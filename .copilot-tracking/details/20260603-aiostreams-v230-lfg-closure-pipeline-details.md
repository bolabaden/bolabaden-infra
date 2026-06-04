<!-- markdownlint-disable-file -->

# Task Details: AIOStreams v2.30 LFG Closure Pipeline Now

## Research Reference

**Source Research**: #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md

## Phase 1: Baseline And Browser/Auth Gate

### Task 1.1: Capture Baseline Runtime State

Collect pre-rerun runtime state and evidence window before any validation actions.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Existing migration evidence baseline to extend.
  * docs/plans/20260603-aiostreams-v230-lfg-closure-pipeline-now-plan.md - Operator-facing closure checklist.
* **Success**:
  * Baseline health and service status are captured.
  * Log window for rerun is timestamped.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 8-40) - Existing internal validation order and reusable gates.
* **Dependencies**:
  * Docker Compose runtime available.

### Task 1.2: Validate Browser Gate And Dashboard Auth

Verify dashboard browser reachability and successful authentication using v2.30 auth model.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Add browser/auth result evidence.
* **Success**:
  * Browser access and login are confirmed.
  * Auth evidence includes timestamp and pass/fail status.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 42-63) - v2.30 auth model and migration behavior.
* **Dependencies**:
  * Task 1.1 completion.

## Phase 2: Import, Runtime, And Restart Persistence

### Task 2.1: Validate Dashboard Import And Immediate Persistence

Run dashboard import and verify the imported artifact persists after reload.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Record import and reload evidence.
* **Success**:
  * Import operation succeeds.
  * Imported item remains after reload.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 27-40) - Existing gate order includes dashboard import and persistence checks.
* **Dependencies**:
  * Task 1.2 completion.

### Task 2.2: Validate Runtime Endpoints And Log Health

Confirm manifest/runtime responses remain healthy and logs show no sustained migration regressions.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Add runtime and logs validation findings.
* **Success**:
  * Runtime endpoint checks pass.
  * No sustained 5xx or recurring migration errors observed.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 25-40) - Manifest/runtime and deep log checks in validated workflow.
* **Dependencies**:
  * Task 2.1 completion.

### Task 2.3: Validate Post-Restart Persistence

Restart `aiostreams` and repeat auth/import/runtime checks to verify persistence across restart.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Add post-restart evidence and status.
* **Success**:
  * Auth still works after restart.
  * Imported state persists after restart.
  * Runtime checks remain healthy after restart.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 27-40) - Restart and persistence verification is mandatory in established flow.
* **Dependencies**:
  * Task 2.2 completion.

## Phase 3: Docs Correctness, Review Closure, And Delivery Gates

### Task 3.1: Validate Documentation Correctness And Close Review

Update closure documentation with observed evidence, validate factual correctness, and close/record review outcomes.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Primary evidence and closure summary.
  * docs/plans/20260603-aiostreams-v230-lfg-closure-pipeline-now-plan.md - Mark checklist completion state.
* **Success**:
  * Every mandatory gate has documented pass/fail evidence.
  * Any unresolved review item has owner and explicit next action.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 76-89) - Closure pass requires concise evidence and explicit gate outcomes.
* **Dependencies**:
  * Phase 2 completion.

### Task 3.2: Execute Commit/Push/PR/CI Closure Handling

Create closure commit, push branch, open/update PR, and capture CI outcome as the final delivery gate.

* **Files**:
  * docs/aiostreams-v230-migration-audit-2026-06-03.md - Append delivery gate status and CI outcome.
* **Success**:
  * Commit and push complete.
  * PR link/status recorded.
  * CI pass/fail status recorded with blocker note if failing.
* **Research References**:
  * \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md (Lines 65-89) - Plan output must be concise, measurable, and closure-oriented.
* **Dependencies**:
  * Task 3.1 completion.

## Dependencies

* Docker Compose runtime and browser access to dashboard.
* GitHub repository access for push/PR/CI verification.

## Success Criteria

* All mandatory gates pass with evidence.
* Documentation reflects observed reality with no unresolved ambiguity.
* Delivery gates (commit/push/PR/CI) are fully recorded.
