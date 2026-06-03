---
title: Infrastructure Master Plan Knowledgebase Ops LFG Pass Plan
type: docs
status: active
date: 2026-06-03
---

# Infrastructure Master Plan Knowledgebase Ops LFG Pass Plan

## Summary

Add a concise knowledgebase operations section to the infrastructure master plan so validation commands and operator access expectations are documented in the same strategic planning artifact.

## Problem Frame

The infrastructure master plan is comprehensive for multi-node architecture, but it lacks a dedicated operational subsection for the MkDocs knowledgebase workflow that now exists in the repository. This creates a gap between strategic planning and day-to-day validation guidance.

## Requirements

- R1. Add a dedicated knowledgebase operations subsection in the infrastructure master plan.
- R2. Include strict build and compose validation commands aligned with current repository practice.
- R3. Clarify routed versus loopback access expectations for docs service operations.
- R4. Keep the change documentation-only with no compose/runtime modifications.

## Key Technical Decisions

- KTD1. Place the new content in `docs/INFRASTRUCTURE_MASTER_PLAN.md` as a planning-level operational bridge.
- KTD2. Reuse validated command patterns already used in repository docs to prevent drift.
- KTD3. Keep the section concise and avoid introducing new architecture claims beyond current implementation.

## Implementation Units

### U1. Add Knowledgebase Operations subsection to infrastructure master plan

- Goal: Document practical MkDocs operations in the strategic infra plan.
- Files: `docs/INFRASTRUCTURE_MASTER_PLAN.md`
- Actions: Add a short subsection covering strict validation commands and access behavior.
- Test Scenarios: Operators can run the listed commands directly and understand expected output and access path.
- Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm runtime parity after docs-only updates

- Goal: Ensure no runtime behavior changes from this pass.
- Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
- Actions: Verification only; no edits expected.
- Test Scenarios: Compose configuration remains valid with existing warning profile.
- Verification: `docker compose config --quiet`

## Risks And Dependencies

- Risk: Plan-level guidance can drift if command examples diverge from main runbook docs.
- Dependency: Existing docs service wiring and MkDocs configuration remain unchanged in this pass.

## Acceptance Examples

- AE1. Given the updated infrastructure master plan, operators can find strict knowledgebase validation commands in that document.
- AE2. Given no runtime-file changes, compose config validation remains successful.