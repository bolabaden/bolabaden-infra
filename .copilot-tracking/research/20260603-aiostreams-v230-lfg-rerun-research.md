<!-- markdownlint-disable-file -->

# Research: AIOStreams v2.30 LFG Rerun Validation and Documentation

## Task and Scope

* Task: prepare a concise, operational implementation plan for an LFG rerun that validates and documents a completed AIOStreams v2.30 migration.
* Scope: validation workflow and documentation updates only; no new migration feature work.

## Tool Evidence and Verified Findings

### Workspace Discovery

* `grep_search` found current AIOStreams v2.30 migration notes in compose and docs.
* Existing plan found: `docs/plans/20260603-aiostreams-v230-migration-closure-plan.md`.
* Existing audit found: `docs/aiostreams-v230-migration-audit-2026-06-03.md`.

### Compose and Runtime Pattern Verification

From `compose/docker-compose.stremio-group.yml`:

* Auth migration variables are present and documented inline:
  * `AIOSTREAMS_AUTH`
  * `AIOSTREAMS_AUTH_ADMINS`
  * `ADDON_PASSWORD` migration note for one startup after upgrade
* v2.30-specific notes are already encoded in comments:
  * intervals expected in seconds
  * deprecated per-service vars removed
  * `ALLOWED_REGEX_PATTERNS*` renamed to `WHITELISTED_REGEX_PATTERNS*`

### Existing Internal Validation Workflow

From `docs/plans/20260603-aiostreams-v230-migration-closure-plan.md`:

* Explicit operational order already used and reusable for rerun:
  1. preflight snapshot
  2. browser auth gate
  3. dashboard import gate
  4. manifest/runtime checks
  5. deep log checks
  6. restart/persistence verification
* Existing acceptance criteria align with rerun objective (auth, import persistence, manifest 200, no sustained 5xx, restart stability).

From `docs/aiostreams-v230-migration-audit-2026-06-03.md`:

* Migration state already marked functionally complete with evidence in runtime health, endpoint behavior, and persistence checks.
* Current rerun should focus on re-validating and producing a concise closure artifact, not redefining migration logic.

## External Source Research

Source: `Viren070/AIOStreams` via `github_repo` tool.

### v2.30 Breaking/Migration Guidance

* `CHANGELOG.md` for `2.30.0` confirms breaking/deprecated transitions including `ADDON_PASSWORD` deprecation and auth model updates.
* `packages/docs/content/docs/migrations/v2.30.mdx` confirms:
  * keep `ADDON_PASSWORD` for at least one startup post-upgrade so migration runs
  * dashboard/config access now relies on `AIOSTREAMS_AUTH` users and admin subset via `AIOSTREAMS_AUTH_ADMINS`
  * removed/renamed env vars (including regex whitelist naming updates)

### Runtime/Auth Implementation Signals

* `packages/core/src/utils/auth.ts` shows legacy `ADDON_PASSWORD` migration behavior into managed config access key.
* `packages/core/src/config/bootstrap.ts` and `utils/env.ts` show bootstrap parsing of `AIOSTREAMS_AUTH` and `AIOSTREAMS_AUTH_ADMINS`.

## Project Structure and Planning Targets

* Existing user-facing plans live under `docs/plans/`.
* Existing migration evidence doc lives under `docs/`.
* Task-planning artifacts for agent execution are required in:
  * `.copilot-tracking/plans/`
  * `.copilot-tracking/details/`
  * `.copilot-tracking/prompts/`

## Operational Constraints

* This repo uses Docker Compose service validation patterns (`docker compose ps`, `docker compose logs`, endpoint curl checks).
* Health and observability verification is mandatory in infra workflows.
* Plan must stay concise and execution-ready for an LFG rerun pass.

## Implementation Guidance for Plan Authoring

* Build the rerun as a short 3-phase flow:
  1. Baseline capture (state + evidence window)
  2. Validation rerun gates (auth, import, manifest, logs, restart)
  3. Documentation/closure update (single concise rerun report)
* Keep explicit step order with no optional ambiguity for mandatory gates.
* Include measurable acceptance criteria and concrete deliverables:
  * updated rerun evidence file in `docs/`
  * short plan/checklist entry in `docs/plans/` format
  * pass/fail summary with rollback trigger condition

## Recommended Deliverables for This Task

* A concise implementation checklist (for LFG rerun execution).
* A details spec mapping each step to commands/evidence.
* An implementation prompt that executes plan sequentially and updates tracking/changes.
