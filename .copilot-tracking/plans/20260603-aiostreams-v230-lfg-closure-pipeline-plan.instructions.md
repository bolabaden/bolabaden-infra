***

## applyTo: ".copilot-tracking/changes/20260603-aiostreams-v230-lfg-closure-pipeline-changes.md"

<!-- markdownlint-disable-file -->

# Task Checklist: AIOStreams v2.30 LFG Closure Pipeline Now

## Overview

Execute a closure-only LFG validation pass for the completed AIOStreams v2.30 migration and produce complete evidence for runtime, documentation, and delivery gates.

## Objectives

* Verify browser auth, import behavior, runtime health, and post-restart persistence without migration regressions.
* Close documentation, review, and delivery gates (commit/push/PR/CI) with auditable evidence.

## Research Summary

### Project Files

* docs/plans/20260603-aiostreams-v230-lfg-closure-pipeline-now-plan.md - Operator-facing execution checklist for the closure run.
* docs/aiostreams-v230-migration-audit-2026-06-03.md - Canonical migration evidence artifact to update.

### External References

* \#file:../research/20260603-aiostreams-v230-lfg-rerun-research.md - Verified internal workflow, v2.30 migration constraints, and closure guidance.
* \#githubRepo:"Viren070/AIOStreams v2.30 migrations auth ADDON\_PASSWORD" - Confirms v2.30 auth migration model and deprecations.

### Standards References

* \#file:../../.github/copilot-instructions.md - Infrastructure repo operating patterns, validation expectations, and quality guardrails.

## Implementation Checklist

### \[ ] Phase 1: Baseline And Browser/Auth Gate

* \[ ] Task 1.1: Capture baseline runtime state and evidence window.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 11-24)

* \[ ] Task 1.2: Validate browser gate and dashboard auth.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 26-38)

### \[ ] Phase 2: Import, Runtime, And Restart Persistence

* \[ ] Task 2.1: Validate dashboard import and immediate persistence.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 42-54)

* \[ ] Task 2.2: Validate runtime endpoints and log health.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 56-68)

* \[ ] Task 2.3: Validate post-restart persistence.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 70-83)

### \[ ] Phase 3: Docs Correctness, Review Closure, And Delivery Gates

* \[ ] Task 3.1: Validate docs correctness and close review findings.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 87-100)

* \[ ] Task 3.2: Execute commit/push/PR/CI closure handling.
  * Details: .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md (Lines 102-115)

## Dependencies

* Docker Compose runtime and browser access to AIOStreams dashboard.
* GitHub access for branch push, PR update, and CI status verification.

## Success Criteria

* All mandatory validation gates pass with timestamped evidence.
* Documentation and review closure are complete and factually aligned with observed outputs.
* Delivery gates (commit, push, PR, CI status) are completed and recorded.
