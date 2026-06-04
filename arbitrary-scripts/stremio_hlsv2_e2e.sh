#!/usr/bin/env bash
set -euo pipefail

base="${1:-http://127.0.0.1:11470}"

run_case() {
  local name="$1"
  local media="$2"
  local id="e2e$(date +%s%N | cut -c1-15)"

  local master track segment bytes note trk seg
  master="$(curl -sS --max-time 120 --get "$base/hlsv2/$id/master.m3u8" \
    --data-urlencode "mediaURL=$media" \
    --data 'videoCodecs=h264' \
    --data 'videoCodecs=h265' \
    --data 'videoCodecs=hevc' \
    --data 'audioCodecs=aac' \
    --data 'audioCodecs=mp3' \
    --data 'audioCodecs=opus' \
    --data 'maxAudioChannels=2' \
    -o /tmp/st_hls_master.out -w '%{http_code}' || true)"

  track='-'
  segment='-'
  bytes='0'
  note=''

  if [[ "$master" == '200' ]]; then
    trk="$(awk 'NF && $1 !~ /^#/{print; exit}' /tmp/st_hls_master.out || true)"
    track="$(curl -sS --max-time 120 "$base/hlsv2/$id/$trk" -o /tmp/st_hls_track.out -w '%{http_code}' || true)"
    if [[ "$track" == '200' ]]; then
      seg="$(awk 'NF && $1 !~ /^#/{print; exit}' /tmp/st_hls_track.out || true)"
      segment="$(curl -sS --max-time 180 "$base/hlsv2/$id/$seg" -o /tmp/st_hls_segment.bin -w '%{http_code}' || true)"
      bytes="$(wc -c < /tmp/st_hls_segment.bin 2>/dev/null || echo 0)"
      if [[ "$segment" != '200' ]]; then
        note="$(head -c 180 /tmp/st_hls_segment.bin 2>/dev/null || true)"
      fi
    else
      note="$(head -c 180 /tmp/st_hls_track.out 2>/dev/null || true)"
    fi
  else
    note="$(head -c 180 /tmp/st_hls_master.out 2>/dev/null || true)"
  fi

  printf '%s|%s|%s|%s|%s|%s\n' "$name" "$master" "$track" "$segment" "$bytes" "$note"
}

echo 'case|master|track|segment|segment_bytes|note'
run_case archive_mp4 'https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4'
run_case blender_mp4 'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4'
run_case samplelib_mp4 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4'
run_case filesamples_mp4 'https://filesamples.com/samples/video/mp4/sample_640x360.mp4'
run_case w3_hls 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'
run_case aac_m4a 'https://filesamples.com/samples/audio/m4a/sample1.m4a'