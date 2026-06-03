# AIOStreams v2.30 Post-Recreate Rerun Evidence (2026-06-03)

## Scope

Fresh LFG rerun after forced recreate to verify migration stability across runtime env, dashboard auth model, manifest endpoint, DB persistence, and restart behavior.

## Baseline

- `docker compose ps aiostreams traefik stremio stremthru`
- Result: all four services healthy.
- `aiostreams` image: `ghcr.io/viren070/aiostreams`.

## Dashboard Auth And Import Gate

- Browser session reached authenticated page: `https://aiostreams.bolabaden.org/dashboard/settings` (page title `AIOStreams`).
- Dashboard actions menu showed import option: `Import environment variables... 83`.
- Import action executed from dashboard.
- Server-side confirmation after import:
  - `{"module":"dashboard","imported":26,"skippedAsDefault":57,"username":"admin","msg":"env settings imported into db"}`

## Runtime Migration Keys

Present in running aiostreams env:

- `AIOSTREAMS_AUTH`
- `AIOSTREAMS_AUTH_ADMINS`
- `ADDON_PASSWORD`
- `DEFAULT_SERVICE_CREDENTIALS`
- `TMDB_API_KEY`
- `TMDB_ACCESS_TOKEN`
- `MEDIAFUSION_API_PASSWORD`
- `MAX_STREAM_EXPRESSIONS`
- `LOG_FORMAT=json`
- `REGEX_FILTER_ACCESS=trusted`

Deprecated keys check:

- No deprecated migration keys found in runtime env (`MAX_STREAM_EXPRESSION_FILTERS`, `ALLOWED_REGEX_PATTERNS*`, `MEDIAFUSION_API_PASSWORD_FILE`, legacy per-service `DEFAULT_/FORCED_` credential variables).

## Manifest Gate

- `curl -ksSI https://aiostreams.bolabaden.org/stremio/manifest.json | head -n 1` => `HTTP/2 200`
- `curl -fsS https://aiostreams.bolabaden.org/stremio/manifest.json | jq -r '.id,.name,.version'` =>
  - `aiostreams.bolabaden.org`
  - `BadenAIO`
  - `2.30.2`

## DB Persistence Gate

File: `volumes/stremio/addons/aiostreams/data/db.sqlite`

Persisted anime refresh intervals remain second-based:

- `metadata.animeDb.refresh.extendedAnitraktMovies = 86400`
- `metadata.animeDb.refresh.extendedAnitraktTv = 86400`
- `metadata.animeDb.refresh.fribbMappings = 86400`
- `metadata.animeDb.refresh.kitsuImdbMapping = 86400`
- `metadata.animeDb.refresh.manamiDb = 604800`

## Restart Stability

- Service restarted and returned healthy.
- Manifest endpoint remained `HTTP/2 200` with unchanged `id/name/version`.
- Authenticated dashboard page remained accessible after restart at `https://aiostreams.bolabaden.org/dashboard/settings`.
- DB interval values remained unchanged after restart (`86400/604800` set preserved).

## Observed Non-Migration Runtime Errors

- External addon/provider manifest errors (`WebStreamr`, `Nuvio Streams`) and HTML/JSON mismatch.
- One invalid user config event: `Invalid config for new user: Proxy credentials are required`.
- These are runtime/provider/user-config issues; migration key model remains intact.

## Acceptance Outcome

- Baseline health: PASS
- Dashboard auth access: PASS
- Dashboard env import flow: PASS
- Runtime migrated key presence: PASS
- Deprecated key absence: PASS
- Manifest endpoint health and payload: PASS
- DB persistence intervals: PASS
- Post-restart stability: PASS

## Rollback Trigger

- If any mandatory gate fails twice consecutively (auth, import, manifest, persistence, or restart stability), halt rollout and revert to pre-migration compose/env snapshot before reattempt.

Overall post-recreate rerun status: PASS
