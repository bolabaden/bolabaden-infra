# AIOStreams v2.30 Post-Recreate Validation Plan

## Overview

Validate the AIOStreams v2.30 migration with a fresh LFG rerun immediately after forced recreate, and confirm stable behavior across auth, import, env migration keys, persistence, and restart.

## Success Criteria

* Dashboard authentication passes with v2.30 credentials.
* Dashboard import succeeds and remains present after reload.
* Runtime migration env keys are present and active.
* Persisted DB-backed state remains intact through checks and restart.
* No sustained migration-related errors appear after restart.

## Checklist

### Phase 1: Baseline After Forced Recreate

* \[x] Confirm forced recreate completed for the service.
* \[x] Capture baseline health and logs for the rerun window.
* \[x] Record current runtime configuration snapshot for comparison.

### Phase 2: Migration Gate Validation

* \[x] Validate dashboard auth access.
* \[x] Validate dashboard import flow and immediate persistence.
* \[x] Validate runtime migration env keys:
  * \[x] AIOSTREAMS\_AUTH
  * \[x] AIOSTREAMS\_AUTH\_ADMINS
  * \[x] Transitional ADDON\_PASSWORD behavior acknowledged for migration path
* \[x] Validate manifest/runtime endpoint health.
* \[x] Validate DB persistence remains intact during functional checks.

### Phase 3: Post-Restart Stability

* \[x] Restart the service.
* \[x] Re-run auth and import checks after restart.
* \[x] Re-validate DB persistence after restart.
* \[x] Review post-restart logs for migration regressions or recurring failures.

### Phase 4: Closure

* \[x] Publish concise pass/fail summary for each gate.
* \[x] Include rollback trigger if any mandatory gate fails twice.
* \[x] Mark rerun outcome as complete only if all mandatory gates pass.
