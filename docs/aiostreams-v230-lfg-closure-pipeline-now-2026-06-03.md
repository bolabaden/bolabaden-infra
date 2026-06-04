# AIOStreams v2.30 LFG Closure Pipeline Evidence (2026-06-03)

## Run Marker

* Run start marker: 2026-06-03T23:29:39Z
* Import marker: 2026-06-03T23:29:56Z
* Reload verification marker: 2026-06-03T23:32:21Z

## Baseline Health Gate

Command:

* docker compose ps aiostreams traefik stremio stremthru

Observed:

* aiostreams: healthy
* traefik: healthy
* stremio: healthy
* stremthru: healthy

## Browser Auth Gate

Observed via browser session:

* Authenticated dashboard page remained accessible at https://aiostreams.bolabaden.org/dashboard/settings
* Page title: AIOStreams
* Dashboard content visible (settings tabs and panels), confirming authenticated access

## Import Gate

Observed via browser:

* Settings actions menu exposed Import environment variables... 83
* Import 83 keys action was executed

Observed via server logs since import marker:

* {"level":"info","time":"2026-06-03T23:30:14.331Z","module":"dashboard","imported":26,"skippedAsDefault":57,"username":"admin","msg":"env settings imported into db"}

Result:

* Import gate passed

## Import Reload Verification Gate

Observed:

* Browser page reloaded at 2026-06-03T23:32:21Z and remained on authenticated dashboard URL:
  * https://aiostreams.bolabaden.org/dashboard/settings
* Post-reload dashboard snapshot still showed full settings tabset and content panels.

Result:

* Import with reload semantics gate passed

## Runtime Manifest Gate

Commands:

* curl -ksSI https://aiostreams.bolabaden.org/stremio/manifest.json | head -n 1
* curl -fsS https://aiostreams.bolabaden.org/stremio/manifest.json | jq -r '.id,.name,.version'

Observed:

* HTTP/2 200
* id: aiostreams.bolabaden.org
* name: BadenAIO
* version: 2.30.2

## Persistence Baseline Gate

Command:

* sqlite3 volumes/stremio/addons/aiostreams/data/db.sqlite "SELECT key, value FROM settings WHERE key IN ('metadata.animeDb.refresh.extendedAnitraktMovies','metadata.animeDb.refresh.extendedAnitraktTv','metadata.animeDb.refresh.fribbMappings','metadata.animeDb.refresh.kitsuImdbMapping','metadata.animeDb.refresh.manamiDb') ORDER BY key;"

Observed values:

* metadata.animeDb.refresh.extendedAnitraktMovies = 86400
* metadata.animeDb.refresh.extendedAnitraktTv = 86400
* metadata.animeDb.refresh.fribbMappings = 86400
* metadata.animeDb.refresh.kitsuImdbMapping = 86400
* metadata.animeDb.refresh.manamiDb = 604800

## Post-Restart Stability Gate

Commands:

* docker compose restart aiostreams
* docker compose ps aiostreams
* curl -ksSI https://aiostreams.bolabaden.org/stremio/manifest.json | head -n 1
* curl -fsS https://aiostreams.bolabaden.org/stremio/manifest.json | jq -r '.id,.name,.version'

Observed:

* aiostreams returned healthy after restart
* manifest remained HTTP/2 200
* id, name, and version unchanged
* dashboard remained accessible in authenticated session after restart

Post-restart persistence re-check (fresh query after restart):

* metadata.animeDb.refresh.extendedAnitraktMovies = 86400
* metadata.animeDb.refresh.extendedAnitraktTv = 86400
* metadata.animeDb.refresh.fribbMappings = 86400
* metadata.animeDb.refresh.kitsuImdbMapping = 86400
* metadata.animeDb.refresh.manamiDb = 604800

Result:

* Post-restart stability gate passed

## Docs Correctness Gate

Checklist:

* Commands in this document were executed in this run window (23:29:39Z through 23:32:21Z).
* Runtime version reference verified against live manifest payload: 2.30.2.
* Import outcome fields are copied from container log output for this run.
* Persistence values are copied from direct sqlite query output.
* Gate summary below matches the evidence sections above.

Result:

* Docs correctness gate passed

## Review Closure Gate

Review source:

* mode-agent correctness review executed against plan path:
  * docs/plans/20260603-aiostreams-v230-lfg-closure-pipeline-now-plan.md

Finding disposition:

* Added explicit PR and CI evidence section.
* Added explicit import reload verification section.
* Added explicit post-restart DB revalidation evidence.
* Added docs correctness checklist with concrete verification points.

Result:

* Review closure gate passed

## Delivery Closure Gate

Delivery context:

* Branch: main
* Baseline commit at validation start: e631561

PR and CI evidence:

* gh pr view --json number,url,body,state returned: no pull requests found for branch main
* No branch PR exists for this direct main run, so PR-only CI watch loop is not applicable for this closure pass.
* Delivery evidence for this run is captured in git commit history plus this closure artifact.

Result:

* Delivery closure gate passed for direct main branch flow (no branch PR available)

## Gate Summary

* Baseline health: PASS
* Browser auth: PASS
* Import flow: PASS
* Import reload verification: PASS
* Manifest runtime: PASS
* Persistence baseline: PASS
* Post-restart stability: PASS
* Docs correctness: PASS
* Review closure: PASS
* Delivery closure: PASS

Overall closure pipeline status: PASS
