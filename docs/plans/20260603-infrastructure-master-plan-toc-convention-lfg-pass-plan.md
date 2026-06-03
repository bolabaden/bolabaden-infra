***

title: Infrastructure Master Plan TOC Convention LFG Pass Plan
type: docs
status: active
date: 2026-06-03
----------------

# Infrastructure Master Plan TOC Convention LFG Pass Plan

## Summary

Standardize table-of-contents conventions in the infrastructure master plan so nested entries remain predictable as the document grows.

## Problem Frame

The master plan has expanded with nested sections, and repeated edits can introduce inconsistent TOC style choices. A short convention note and formatting pass reduce future drift and navigation ambiguity.

## Requirements

* R1. Keep changes documentation-only and limited to the infrastructure master plan.
* R2. Improve TOC readability without renumbering modules or changing section meaning.
* R3. Preserve existing anchor targets and section references.
* R4. Validate strict docs build and compose configuration after edits.

## Key Technical Decisions

* KTD1. Apply minimal text edits that clarify TOC style rather than restructuring the document.
* KTD2. Keep existing heading IDs intact to avoid breaking inbound links.

## Implementation Units

### U1. Add TOC convention guidance and align nearby formatting

* Goal: Keep navigation style explicit and maintainable for future edits.
* Files: `docs/INFRASTRUCTURE_MASTER_PLAN.md`
* Actions: Add a concise TOC convention note and normalize the nested item style near section 3.
* Test Scenarios: Readers can distinguish top-level and nested TOC entries with no ambiguity.
* Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm docs/runtime parity

* Goal: Ensure docs-only edits do not affect runtime config behavior.
* Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
* Actions: Validation-only, no runtime edits.
* Test Scenarios: `docker compose config --quiet` remains successful with existing warning profile.
* Verification: `docker compose config --quiet`

## Risks And Dependencies

* Risk: Over-editing TOC text could reduce readability if style is too verbose.
* Dependency: Current MkDocs configuration remains unchanged during this pass.

## Acceptance Examples

* AE1. Infrastructure master plan includes a clear TOC convention statement for nested entries.
* AE2. Strict docs build and compose validation continue to pass.
