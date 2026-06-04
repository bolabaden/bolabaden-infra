***

title: Infrastructure Master Plan Observability Checks LFG Pass Plan
type: docs
status: active
date: 2026-06-03
----------------

# Infrastructure Master Plan Observability Checks LFG Pass Plan

## Summary

Add a compact observability-oriented verification note to the infrastructure master plan so operators can quickly confirm docs and edge stack health during troubleshooting.

## Problem Frame

The master plan already includes architecture and operational guidance, but lightweight observability checks are easier to apply when grouped with existing Knowledgebase Operations content.

## Requirements

* R1. Keep edits docs-only and limited to `docs/INFRASTRUCTURE_MASTER_PLAN.md`.
* R2. Add read-only observability checks for key edge services.
* R3. Preserve existing anchors and TOC behavior.
* R4. Validate strict docs build and compose config after edits.

## Key Technical Decisions

* KTD1. Use existing service names from current compose usage.
* KTD2. Keep guidance short and copy-paste ready.

## Implementation Units

### U1. Add observability check note in Knowledgebase Operations

* Goal: Make operational diagnostics faster without changing runtime behavior.
* Files: `docs/INFRASTRUCTURE_MASTER_PLAN.md`
* Actions: Add concise bullets for read-only service state and log inspections.
* Test Scenarios: Operators can run the listed commands and immediately inspect edge service status.
* Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm compose/runtime parity

* Goal: Ensure docs-only changes do not alter runtime configuration.
* Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
* Actions: Validation only.
* Test Scenarios: `docker compose config --quiet` remains successful with existing warning profile.
* Verification: `docker compose config --quiet`

## Risks And Dependencies

* Risk: Service names may change over time and require command refresh.
* Dependency: Current compose service naming remains stable.

## Acceptance Examples

* AE1. Infrastructure master plan includes observability check guidance under Knowledgebase Operations.
* AE2. Strict docs build and compose validation continue to pass.
