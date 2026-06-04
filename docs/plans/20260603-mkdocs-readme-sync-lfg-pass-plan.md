***

title: MkDocs Knowledgebase README Sync LFG Pass Plan
type: docs
status: active
date: 2026-06-03
----------------

# MkDocs Knowledgebase README Sync LFG Pass Plan

## Summary

Align repository documentation with the current MkDocs knowledgebase behavior so operators can run strict validation with accurate expectations and less ambiguity.

## Problem Frame

The knowledgebase implementation is now stable, but the operator-facing documentation can drift from current behavior unless it is kept in sync. This pass updates the canonical runbook text to reflect the active docs boundary and strict-validation workflow.

## Requirements

* R1. README knowledgebase guidance must describe the active docs boundary model clearly.
* R2. The change must not alter runtime compose behavior or routing.
* R3. Strict MkDocs validation must continue to pass after documentation updates.
* R4. Compose config validation must remain successful.

## Key Technical Decisions

* KTD1. Keep this pass documentation-focused: update README guidance instead of changing compose or service wiring.
* KTD2. Preserve the current `mkdocs.yml` behavior and avoid changing navigation or excludes in this pass.

## Implementation Units

### U1. Synchronize README knowledgebase section with current MkDocs behavior

* Goal: Make the operator runbook match the current knowledgebase architecture and validation workflow.
* Files: `README.md`
* Actions: Update knowledgebase wording for docs boundary behavior and strict validation expectations.
* Test Scenarios: A new operator should be able to run strict validation commands directly from README guidance.
* Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm compose parity after docs-only change

* Goal: Ensure documentation-only edits do not affect runtime configuration validity.
* Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
* Actions: Verification only; no edits expected.
* Test Scenarios: Compose config remains valid with existing environment warning profile.
* Verification: `docker compose config --quiet`

## Risks And Dependencies

* Risk: README wording that is too broad may become stale quickly.
* Dependency: Current mkdocs and compose wiring remains unchanged during this pass.

## Acceptance Examples

* AE1. Given updated README guidance, when strict MkDocs build runs, then the command succeeds without new validation failures.
* AE2. Given no runtime file edits, when compose config is validated, then it remains successful with only existing environment warnings.
