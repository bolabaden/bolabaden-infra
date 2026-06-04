---
applyTo: ".copilot-tracking/changes/20260603-aiostreams-v230-lfg-rerun-changes.md"
---

<!-- markdownlint-disable-file -->

# Task Checklist: AIOStreams v2.30 LFG Rerun Validation (Post-Recreate)

## Overview

Run a fresh LFG rerun after forced recreate and validate AIOStreams v2.30 migration behavior end-to-end with concise evidence.

## Objectives

- Verify dashboard auth and import behavior with v2.30 auth model.
- Verify runtime migration env keys, DB persistence, and post-restart stability.

## Research Summary

### Project Files

- compose/docker-compose.stremio-group.yml - Source of runtime env migration keys and v2.30 notes.
- docs/plans/20260603-aiostreams-v230-migration-closure-plan.md - Existing ordered validation workflow.
- docs/aiostreams-v230-migration-audit-2026-06-03.md - Prior baseline evidence to compare rerun results.

### External References

- #file:../research/20260603-aiostreams-v230-lfg-rerun-research.md - Verified findings and rerun guidance.
- #githubRepo:"Viren070/AIOStreams packages/docs/content/docs/migrations/v2.30.mdx" - Migration key and auth behavior requirements.

## Implementation Checklist

### [ ] Phase 1: Forced-Recreate Baseline

- [ ] Task 1.1: Confirm forced recreate completed and capture baseline runtime state
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 11-23)

- [ ] Task 1.2: Validate runtime env migration keys loaded for v2.30
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 25-39)

### [ ] Phase 2: Functional Migration Gates

- [ ] Task 2.1: Validate dashboard auth and dashboard import
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 43-55)

- [ ] Task 2.2: Validate manifest/runtime and DB persistence
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 57-71)

### [ ] Phase 3: Restart Stability and Closure

- [ ] Task 3.1: Restart and verify post-restart stability with no migration regressions
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 75-88)

- [ ] Task 3.2: Publish concise pass/fail rerun closure note
  - Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-rerun-details.md (Lines 90-103)

## Dependencies

- Docker Compose runtime access and logs.
- Existing AIOStreams dashboard route and credentials for auth validation.

## Success Criteria

- Dashboard auth/import checks pass with evidence.
- Runtime env migration keys are validated as active.
- DB persistence survives recreate and restart checks.
- Post-restart stability passes with no sustained migration-related errors.
