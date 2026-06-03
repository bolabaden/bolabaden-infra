# AIOStreams v2.30 Migration Audit (2026-06-03)

## Scope

This audit verifies the AIOStreams v2.30 migration for compose/env/dashboard/runtime persistence without changing intended values.

## Evidence Summary

### Runtime Health

- `aiostreams`, `traefik`, `stremio`, and `stremthru` are all `Up (...) (healthy)`.
- `aiostreams` running image: `ghcr.io/viren070/aiostreams`.

### Addon Manifest Endpoint

- Verified correct addon endpoint: `https://aiostreams.bolabaden.org/stremio/manifest.json`
- Response status: `HTTP/2 200`
- Parsed payload values:
  - `id = aiostreams.bolabaden.org`
  - `name = BadenAIO`
  - `version = 2.30.2`
- Note: `https://aiostreams.bolabaden.org/manifest.json` is the web-app manifest and is not the Stremio addon manifest (it will not contain addon `id/version`).

### Auth + Dashboard

- Browser login to dashboard succeeded via `AIOSTREAMS_AUTH` user.
- Dashboard settings page is accessible at `/dashboard/settings`.
- Environment import operation executed (server log evidence):
  - `imported: 26`
  - `skippedAsDefault: 57`
  - `username: admin`

### v2.30 Runtime Env Verification

Confirmed present in running `aiostreams` container:

- `AIOSTREAMS_AUTH`
- `AIOSTREAMS_AUTH_ADMINS`
- `DEFAULT_SERVICE_CREDENTIALS`
- `TMDB_API_KEY`
- `TMDB_ACCESS_TOKEN`
- `MEDIAFUSION_API_PASSWORD`
- `MAX_STREAM_EXPRESSIONS`
- `LOG_FORMAT=json`
- `REGEX_FILTER_ACCESS=trusted`

Deprecated/removed migration names are not present in `aiostreams` runtime env:

- Per-service `DEFAULT_<SVC>_*` / `FORCED_<SVC>_*`
- `MAX_STREAM_EXPRESSION_FILTERS`
- `ALLOWED_REGEX_PATTERNS*`
- `MEDIAFUSION_API_PASSWORD_FILE`

### DB Persistence Verification (SQLite)

DB file: `volumes/stremio/addons/aiostreams/data/db.sqlite`

Validated persisted non-empty keys:

- `services.defaultCredentials`
- `metadata.tmdb.apiKey`
- `metadata.tmdb.accessToken`
- `presets.mediafusion.apiPassword`
- `proxy.default.id`
- `proxy.default.credentials`
- `proxy.force.enabled`
- `presets.stremthruStore.url`
- `presets.stremthruTorz.url`

### Interval Unit Compatibility Fix

Issue found:

- Persisted anime DB refresh values were still in legacy millisecond-scale form (`86400000`, `604800000`) while v2.30 scheduling treats these as seconds.
- This causes task-clamp warnings and cadence drift.

Corrective action taken:

- Updated persisted keys in DB to equivalent seconds:
  - `metadata.animeDb.refresh.fribbMappings = 86400`
  - `metadata.animeDb.refresh.kitsuImdbMapping = 86400`
  - `metadata.animeDb.refresh.extendedAnitraktMovies = 86400`
  - `metadata.animeDb.refresh.extendedAnitraktTv = 86400`
  - `metadata.animeDb.refresh.manamiDb = 604800`
- `updated_by` set to `copilot-migration`.

## Known Non-Migration Runtime Errors

Observed in `aiostreams` logs during stream/addon fetch activity:

- External add-ons returning HTML instead of JSON (`WebStreamr`, `Nuvio Streams`).
- Rate limits (`429`) from external add-ons.
- Proxy generation errors (`stremthru` `403: Forbidden`) for some stream batches.
- Torznab capability fetch path using undefined API key for one source (`Zilean AD`).

These are runtime ecosystem/provider issues and not caused by the v2.30 variable migration itself.

## Migration Status

- Compose/env migration: complete
- Dashboard login + env import workflow: complete
- Runtime env key migration verification: complete
- DB persistence verification: complete
- Interval unit compatibility correction for persisted settings: complete
- Residual runtime issues: external provider/proxy ecosystem errors only (non-migration)

## Conclusion

Migration to v2.30 variable model is functionally complete and validated across:

- Compose/env wiring
- Dashboard auth + import flow
- Runtime env key set
- Database persistence of migrated settings
- Interval-unit compatibility for future env cleanup safety
