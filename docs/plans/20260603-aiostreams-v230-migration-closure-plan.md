***

title: AIOStreams v2.30 Migration Closure Plan
type: docs
status: active
date: 2026-06-03
----------------

# AIOStreams v2.30 Migration Closure Plan

## Goals

* Close migration with exhaustive, no-gap validation across browser and terminal paths.
* Prove v2.30 auth + dashboard behavior works after compose migration commits.
* Capture pass/fail evidence and exit with clear acceptance or rollback trigger.

## Scope

* In scope: runtime verification only (no new compose edits).
* Out of scope: feature additions, tuning, or unrelated stack changes.

## Verification Steps

1. Preflight snapshot
   * Record current image, uptime, and health: `docker compose ps aiostreams traefik stremio stremthru`
   * Save recent logs for baseline: `docker compose logs --since 20m aiostreams traefik stremio stremthru > /tmp/aiostreams-v230-baseline.log`

2. Browser auth gate (mandatory)
   * Open `https://aiostreams.$DOMAIN/` in a clean/private session.
   * Confirm login prompt appears (v2.30 auth active).
   * Login with a user from `AIOSTREAMS_AUTH` and verify dashboard loads without 401/500.

3. Dashboard import gate (mandatory)
   * In dashboard, go to Settings/Import workflow.
   * Import the known-good migration payload (the backup/export used for migration validation).
   * Confirm import success toast/message and no field-mapping or credential parse errors.
   * Reload page once and confirm imported values persist.

4. Addon manifest/runtime checks
   * Validate addon manifest responds: `curl -fsS https://aiostreams.$DOMAIN/stremio/manifest.json | jq -r '.id,.name,.version'`
   * Validate addon manifest endpoint resolves: `curl -fsSI https://aiostreams.$DOMAIN/stremio/manifest.json | head -n 1`
   * Optional web-app check: `curl -fsSI https://aiostreams.$DOMAIN/manifest.json | head -n 1`
   * Confirm Traefik route for Host(`aiostreams.$DOMAIN`) is healthy from dashboard/API view.

5. Terminal deep verification
   * Inspect container logs post-login/import: `docker compose logs --since 10m aiostreams`
   * Inspect proxy/edge logs for routing/auth failures: `docker compose logs --since 10m traefik stremio stremthru`
   * Required result: no uncaught exceptions, migration/auth loop errors, or repeated 5xx for aiostreams routes.

6. Persistence check
   * Restart only aiostreams: `docker compose restart aiostreams`
   * Re-test login and one dashboard page load.
   * Re-run manifest curl check to confirm stable post-restart behavior.

## Acceptance Criteria

* Browser login is required and succeeds with v2.30 auth credentials.
* Dashboard import completes and imported settings persist after reload.
* `https://aiostreams.$DOMAIN/stremio/manifest.json` returns HTTP 200 and contains expected addon `id`/`name`/`version`.
* aiostreams routing returns no persistent 4xx/5xx regressions.
* Logs across aiostreams/traefik/stremio/stremthru show no migration-breaking errors during test window.
* Restart does not regress auth, import state, or manifest availability.

## Rollback Note

* Trigger rollback if any mandatory gate fails twice after a clean retry.
* Rollback action: restore prior known-good aiostreams image tag and restore pre-validation `./volumes/stremio/addons/aiostreams/data` backup (including sqlite data), then redeploy service and re-run preflight + addon-manifest checks + auth/dashboard gate.
