<!-- markdownlint-disable-file -->

# Task Details: AIOStreams v2.30 LFG Rerun Validation (Post-Recreate)

## Research Reference

**Source Research**: #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md

## Phase 1: Forced-Recreate Baseline

### Task 1.1: Confirm forced recreate and capture baseline state

Confirm the rerun starts from a newly recreated AIOStreams container and capture baseline health/log state.

- **Files**:
  - docs/plans/20260603-aiostreams-v230-migration-closure-plan.md - Existing gate order and baseline command model.
- **Success**:
  - Forced-recreate run for `aiostreams` is evidenced in command output/history.
  - Baseline status/log snapshot is captured for `aiostreams`, `traefik`, `stremio`, and `stremthru`.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 13-23) - Verified workspace/runtime context.
- **Dependencies**:
  - Docker Compose access.

### Task 1.2: Validate runtime env migration keys for v2.30

Validate migration-critical env keys are present and aligned with v2.30 semantics.

- **Files**:
  - compose/docker-compose.stremio-group.yml - Canonical env key source.
- **Success**:
  - `AIOSTREAMS_AUTH` and `AIOSTREAMS_AUTH_ADMINS` are configured as expected.
  - Transitional `ADDON_PASSWORD` behavior and v2.30 key migration notes are acknowledged.
  - Removed/renamed legacy patterns are not treated as active migration targets.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 24-40) - Compose migration key findings.
  - #githubRepo:"Viren070/AIOStreams packages/docs/content/docs/migrations/v2.30.mdx" - Upstream migration requirements.
- **Dependencies**:
  - Task 1.1 completion.

## Phase 2: Functional Migration Gates

### Task 2.1: Validate dashboard auth and import behavior

Run dashboard-level validation gates in strict sequence to confirm migrated auth model and import behavior.

- **Files**:
  - docs/plans/20260603-aiostreams-v230-migration-closure-plan.md - Reused gate sequence.
- **Success**:
  - Dashboard authentication succeeds using v2.30 auth credentials.
  - Dashboard import succeeds and remains available after UI reload.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 41-51) - Existing validation sequence.
- **Dependencies**:
  - Phase 1 completion.

### Task 2.2: Validate manifest/runtime health and DB persistence

Validate runtime endpoint behavior and confirm persisted migration state survives operation checks.

- **Files**:
  - docs/aiostreams-v230-migration-audit-2026-06-03.md - Baseline persistence and runtime comparisons.
- **Success**:
  - `/stremio/manifest.json` returns HTTP 200 and expected service metadata.
  - DB-backed/imported state remains present and unchanged during rerun checks.
  - No migration-critical runtime failures are detected in the rerun window.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 52-59) - Rerun focus on regression absence.
  - #githubRepo:"Viren070/AIOStreams CHANGELOG 2.30.0" - Migration stability expectations.
- **Dependencies**:
  - Task 2.1 completion.

## Phase 3: Restart Stability and Closure

### Task 3.1: Validate post-restart stability

Restart `aiostreams` and confirm auth/import/runtime/db behavior remains stable.

- **Files**:
  - docs/aiostreams-v230-migration-audit-2026-06-03.md - Add post-restart verification evidence.
- **Success**:
  - Post-restart dashboard auth/import checks still pass.
  - DB persistence remains intact after restart.
  - No sustained migration-related errors appear in post-restart logs.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 60-95) - Closure evidence and acceptance model.
- **Dependencies**:
  - Phase 2 completion.

### Task 3.2: Publish concise rerun closure note

Publish a concise pass/fail summary with rollback trigger guidance.

- **Files**:
  - docs/aiostreams-v230-migration-audit-2026-06-03.md - Append rerun summary.
  - docs/plans/20260603-aiostreams-v230-migration-closure-plan.md - Mark rerun status/closure.
- **Success**:
  - Closure note includes timestamp, gate outcomes, and evidence pointers.
  - Rollback trigger condition is explicit if mandatory gates fail.
- **Research References**:
  - #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 74-95) - Deliverable model.
- **Dependencies**:
  - Task 3.1 completion.

## Dependencies

- Docker Compose CLI and access to running stack.
- Existing docs artifacts in `docs/` and `docs/plans/`.

## Success Criteria

- Forced-recreate rerun is validated with evidence.
- Dashboard auth/import and runtime env migration key checks pass.
- DB persistence and post-restart stability checks pass.
