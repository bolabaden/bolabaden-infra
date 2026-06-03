# AIOStreams v2.30 Closure Validation LFG Rerun Evidence (2026-06-03)

## Run Markers

- Rerun start marker: 2026-06-03T23:35:50Z
- Import marker (first attempt): 2026-06-03T23:36:18Z
- Import marker (successful sequence): 2026-06-03T23:36:48Z

## Auth Gate

Browser evidence:
- URL remained at https://aiostreams.bolabaden.org/dashboard/settings
- Page title remained AIOStreams
- Dashboard tabs and settings panels were visible in snapshots.

Result: PASS

## Import Gate

Import action:
- Settings actions menu opened.
- Import environment variables action triggered.
- Import 83 keys action clicked.

Server log evidence:
- {"level":"info","time":"2026-06-03T23:37:52.386Z","module":"dashboard","imported":26,"skippedAsDefault":57,"username":"admin","msg":"env settings imported into db"}

Result: PASS

## Reload Gate

Action:
- Dashboard page reloaded after import.

Evidence:
- URL remained https://aiostreams.bolabaden.org/dashboard/settings
- Dashboard content still rendered after reload.

Result: PASS

## Restart Persistence Gate

Actions:
- docker compose restart aiostreams
- docker compose ps aiostreams

Evidence:
- aiostreams returned to healthy status.
- Post-restart DB values remained unchanged:
  - metadata.animeDb.refresh.extendedAnitraktMovies = 86400
  - metadata.animeDb.refresh.extendedAnitraktTv = 86400
  - metadata.animeDb.refresh.fribbMappings = 86400
  - metadata.animeDb.refresh.kitsuImdbMapping = 86400
  - metadata.animeDb.refresh.manamiDb = 604800

Result: PASS

## Runtime Endpoint Gate

Manifest evidence:
- HTTP status: HTTP/2 200
- id: aiostreams.bolabaden.org
- name: BadenAIO
- version: 2.30.2

Result: PASS

## Browser Test Gate

Browser execution evidence:
- Opened authenticated dashboard page in browser tooling at https://aiostreams.bolabaden.org/dashboard/settings
- Verified visible UI structure after reload/restart: dashboard header plus settings tab groups (General, Branding, Templates, Metadata, Logging, HTTP, Proxy, Services, Presets, Built-ins, Posters, Resources, User Limits, Recursion, Tasks, Analytics).
- Verified page title remained AIOStreams throughout rerun path.

Result: PASS

## Review Closure And Residual Readiness

- This rerun artifact contains concrete timestamped evidence for all validation gates from the plan.
- Any additional review findings from step 3 can be applied directly against this file before residual handling.

## Residual Handling Gate

Residual ledger:
- Residuals: none
- Owner: n/a
- Disposition: all step-3 findings applied in this artifact

Result: PASS

## Commit/Push/PR/CI Handling Gate

Current state during step-4 persistence:
- Branch: feat/aiostreams-lfg-rerun-closure-20260603
- Review fixes are committed and pushed in step 4.
- PR and CI evidence will be recorded after step 7 and step 8 complete.

Result: IN_PROGRESS

Current closure validation status: IN_PROGRESS
