# AIOStreams v2.30 LFG Closure Pipeline Plan (Now)

## Overview
Run a closure-only LFG pass for the already completed v2.30 migration and produce auditable evidence for auth, import, persistence, docs correctness, review closure, browser gate, and delivery gates.

## Preconditions
- Migration implementation is already deployed and healthy.
- Operator has dashboard credentials defined via `AIOSTREAMS_AUTH`.
- Existing evidence docs are present and writable.

## Mandatory Gates
- Browser gate: dashboard reachable in browser and auth works.
- Import gate: dashboard import succeeds and remains visible after reload.
- Post-restart persistence gate: imported config/state survives service restart.
- Runtime health gate: manifest/runtime endpoint checks remain successful.
- Docs correctness gate: rerun evidence and closure notes accurately reflect observed results.
- Review closure gate: all findings resolved or explicitly documented with owner and follow-up.
- Delivery gate: commit, push, PR, and CI status captured.

## Execution Checklist

### Phase 1: Baseline And Browser/Auth Validation
- [ ] Capture pre-rerun snapshot (`docker compose ps`, relevant service logs tail).
- [ ] Open dashboard in browser and validate login/auth flow.
- [ ] Record auth evidence in closure notes (timestamp + result).

### Phase 2: Import And Runtime Validation
- [ ] Import target dashboard config.
- [ ] Verify imported artifact appears and survives immediate reload.
- [ ] Validate runtime endpoint behavior and absence of sustained 5xx.
- [ ] Record command/browser evidence for each gate.

### Phase 3: Restart And Persistence Validation
- [ ] Restart `aiostreams`.
- [ ] Re-check dashboard auth after restart.
- [ ] Re-check imported artifact/state persistence after restart.
- [ ] Re-check runtime endpoints and logs for migration regressions.

### Phase 4: Documentation And Review Closure
- [ ] Update rerun evidence doc with pass/fail for each mandatory gate.
- [ ] Validate docs for correctness against observed command/browser output.
- [ ] Close review items or document explicit residuals (owner + next action).

### Phase 5: Delivery Closure (Git/PR/CI)
- [ ] Commit closure artifacts with conventional commit message.
- [ ] Push branch and open/update PR.
- [ ] Capture CI status; resolve failures or document blocker.
- [ ] Mark closure complete only if all mandatory gates pass.

## Exit Criteria
- Every mandatory gate is marked pass with concrete evidence.
- Closure docs are accurate and up to date.
- PR is open/updated and CI outcome is recorded.
