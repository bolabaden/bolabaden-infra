#!/usr/bin/env bash
set -euo pipefail

container="${1:-stremio}"
tmp_js="/tmp/stremio_hls_runtime_patch.js"
tmp_server="/tmp/stremio_server.js"

cat >"$tmp_js" <<'EOF'
const fs = require('fs');

const filePath = process.argv[2];
let source = fs.readFileSync(filePath, 'utf8');

const apply = (needle, replacement, label) => {
  if (source.includes(replacement)) {
    console.log(`already patched: ${label}`);
    return;
  }
  if (!source.includes(needle)) {
    throw new Error(`patch target not found: ${label}`);
  }
  source = source.replace(needle, replacement);
  console.log(`patched: ${label}`);
};

apply(
  `if ("number" != typeof format.duration) throw new Error("Live media is not supported");`,
  `if ("number" != typeof format.duration) { format.duration = 3600; }`,
  'live-duration-guard'
);

apply(
  `            function onFinished(error) {\n                cleanup(), stream.off("readable", read), size === 1 / 0 && chunks.length > 0 ? resolve(Buffer.concat(chunks)) : reject(error || new Error("stream ended"));\n            }`,
  `            function onFinished(error) {\n                cleanup(), stream.off("readable", read), chunks.length > 0 ? resolve(Buffer.concat(chunks)) : reject(error || new Error("stream ended"));\n            }`,
  'stream-reader-partial-buffer'
);

apply(
  `            let playlist;\n            try {\n                playlist = await req.converter.playlist(req.params.track);\n            } catch (error) {\n                return console.error(error), res.statusCode = 500, res.setHeader("content-type", "application/json"), \n                void res.end(JSON.stringify({\n                    error: {\n                        code: ERROR_CODE.READ_PLAYLIST_FAILED,\n                        message: \`Failed to read hls playlist: \${error.message}\`\n                    }\n                }));\n            }\n            res.setHeader("content-type", "application/vnd.apple.mpegurl"), res.setHeader("content-length", Buffer.byteLength(playlist)), \n            res.end(playlist);`,
  `            let playlist;\n            try {\n                playlist = await req.converter.playlist(req.params.track);\n            } catch (error) {\n                if (error && "stream ended" === error.message) {\n                    await new Promise((resolve => setTimeout(resolve, 250)));\n                    try {\n                        playlist = await req.converter.playlist(req.params.track);\n                    } catch (retryError) {\n                        error = retryError;\n                    }\n                }\n                if (!playlist) return console.error(error), res.statusCode = 500, res.setHeader("content-type", "application/json"), \n                void res.end(JSON.stringify({\n                    error: {\n                        code: ERROR_CODE.READ_PLAYLIST_FAILED,\n                        message: \`Failed to read hls playlist: \${error.message}\`\n                    }\n                }));\n            }\n            res.setHeader("content-type", "application/vnd.apple.mpegurl"), res.setHeader("content-length", Buffer.byteLength(playlist)), \n            res.end(playlist);`,
  'playlist-retry-on-stream-ended'
);

apply(
  `            const sequenceNumber = parseInt(req.params.sequenceNumber, 10);\n            let mediaSegment;\n            try {\n                mediaSegment = await req.converter.mediaSegment(req.params.track, sequenceNumber);\n            } catch (error) {\n                return console.error(error), res.statusCode = 500, res.setHeader("content-type", "application/json"), \n                void res.end(JSON.stringify({\n                    error: {\n                        code: ERROR_CODE.READ_MEDIA_SEGMENT_FAILED,\n                        message: \`Failed to read media segment: \${error.message}\`\n                    }\n                }));\n            }\n            res.setHeader("content-type", "m4s" === req.params.ext ? "video/mp4" : "text/vtt"), \n            res.setHeader("content-length", mediaSegment.length), res.end(mediaSegment);`,
  `            const sequenceNumber = parseInt(req.params.sequenceNumber, 10);\n            let mediaSegment;\n            try {\n                mediaSegment = await req.converter.mediaSegment(req.params.track, sequenceNumber);\n            } catch (error) {\n                if (error && "stream ended" === error.message) {\n                    await new Promise((resolve => setTimeout(resolve, 250)));\n                    try {\n                        mediaSegment = await req.converter.mediaSegment(req.params.track, sequenceNumber);\n                    } catch (retryError) {\n                        error = retryError;\n                    }\n                }\n                if (!mediaSegment) return console.error(error), res.statusCode = 500, res.setHeader("content-type", "application/json"), \n                void res.end(JSON.stringify({\n                    error: {\n                        code: ERROR_CODE.READ_MEDIA_SEGMENT_FAILED,\n                        message: \`Failed to read media segment: \${error.message}\`\n                    }\n                }));\n            }\n            res.setHeader("content-type", "m4s" === req.params.ext ? "video/mp4" : "text/vtt"), \n            res.setHeader("content-length", mediaSegment.length), res.end(mediaSegment);`,
  'segment-retry-on-stream-ended'
);

fs.writeFileSync(filePath, source);
EOF

docker cp "$container":/srv/stremio-server/server.js "$tmp_server"
node "$tmp_js" "$tmp_server"
node --check "$tmp_server"
docker cp "$tmp_server" "$container":/srv/stremio-server/server.js
docker restart "$container" >/dev/null

for i in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:11470/ || true)"
  if [[ "$code" != "000" ]]; then
    echo "stremio up: http=$code try=$i"
    exit 0
  fi
  sleep 1
done

echo "stremio did not become ready in time" >&2
exit 1