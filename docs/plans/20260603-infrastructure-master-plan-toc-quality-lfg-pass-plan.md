***

title: Infrastructure Master Plan TOC Quality LFG Pass Plan
type: docs
status: active
date: 2026-06-03
----------------

# Infrastructure Master Plan TOC Quality LFG Pass Plan

## Summary

Improve navigation clarity in the infrastructure master plan by tightening table-of-contents formatting and reducing ambiguity for subsection linking.

## Problem Frame

The infrastructure master plan has evolved with additional subsections, but table-of-contents formatting consistency can degrade as sections are inserted over time. This pass performs a focused quality pass so operators can navigate reliably.

## Requirements

* R1. Keep edits scoped to documentation-only changes in the infrastructure master plan.
* R2. Ensure TOC formatting remains clear and stable for primary and nested sections.
* R3. Preserve existing section anchors and document meaning.
* R4. Validate strict docs build and compose config after edits.

## Key Technical Decisions

* KTD1. Apply minimal textual edits to preserve existing structure while improving readability.
* KTD2. Avoid changing module numbering or architecture semantics in this pass.

## Implementation Units

### U1. Refine TOC formatting in infrastructure master plan

* Goal: Ensure section hierarchy is obvious and predictable in the TOC.
* Files: `docs/INFRASTRUCTURE_MASTER_PLAN.md`
* Actions: Normalize nested TOC entry styling and add concise clarity text where needed.
* Test Scenarios: Readers can identify top-level and nested sections without ambiguity.
* Verification: `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm docs/runtime validation parity

* Goal: Ensure docs-only changes do not impact runtime configuration.
* Files: `docker-compose.yml`, `compose/docker-compose.docs.yml`
* Actions: Validation only; no runtime edits expected.
* Test Scenarios: Compose config remains valid with existing warning profile.
* Verification: `docker compose config --quiet`

## Risks And Dependencies

* Risk: Over-editing headings could unintentionally affect legacy inbound links.
* Dependency: Existing docs publishing pipeline and mkdocs.yml remain unchanged.

## Acceptance Examples

* AE1. Table-of-contents hierarchy in the infrastructure master plan is clearer after the pass.
* AE2. Strict docs build and compose validation continue to pass.
