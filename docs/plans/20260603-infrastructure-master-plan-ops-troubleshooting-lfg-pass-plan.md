***

title: Infrastructure Master Plan Ops Troubleshooting LFG Pass Plan
type: docs
status: active
date: 2026-06-03
----------------

# Infrastructure Master Plan Ops Troubleshooting LFG Pass Plan

## Summary

Extend the infrastructure master plan with concise operational troubleshooting checks so docs and service-state diagnostics are discoverable in the same planning document.

## Problem Frame

The master plan documents architecture and module strategy, but quick operational checks for documentation service and edge proxy troubleshooting are easier to execute when co-located with existing Knowledgebase Operations guidance.

## Requirements

* R1. Keep this pass documentation-only and scoped to infrastructure plan guidance.
* R2. Add a short troubleshooting subsection with concrete log/health commands.
* R3. Preserve existing section anchors and TOC links.
* R4. Revalidate strict docs build and compose config after edits.

## Key Technical Decisions

* KTD1. Reuse existing service names already used in the stack to avoid speculative commands.
* KTD2. Keep troubleshooting commands read-only and operator-safe.

## Implementation Units

### U1. Add troubleshooting checks under Knowledgebase Operations

* Goal: Provide quick diagnostics for docs routing and service health.
* Files: `docs/INFRASTRUCTURE_MASTER_PLAN.md`
* Actions: Add short bullet list with read-only compose/log commands near section 3.1.
* Test Scenarios: Operators can copy-paste commands to inspect docs and edge services without altering runtime state.
* Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm runtime-parity validation

* Goal: Ensure docs-only changes do not alter runtime config behavior.
* Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
* Actions: Verification only.
* Test Scenarios: `docker compose config --quiet` remains successful with existing warning profile.
* Verification: `docker compose config --quiet`

## Risks And Dependencies

* Risk: Command examples can drift if service names change later.
* Dependency: Existing service names in compose remain current.

## Acceptance Examples

* AE1. Infrastructure plan includes a compact troubleshooting command set under Knowledgebase Operations.
* AE2. Strict docs build and compose validation continue to pass.
