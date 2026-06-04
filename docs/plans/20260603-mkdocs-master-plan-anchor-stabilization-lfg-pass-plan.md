***

title: MkDocs Master Plan Anchor Stabilization LFG Pass Plan
type: fix
status: active
date: 2026-06-03
----------------

# MkDocs Master Plan Anchor Stabilization LFG Pass Plan

## Summary

Stabilize broken table-of-contents links in the infrastructure master plan by assigning explicit heading IDs to the affected sections so MkDocs resolves in-page anchors consistently.

***

## Problem Frame

Strict MkDocs builds currently report multiple missing in-page anchors in `docs/INFRASTRUCTURE_MASTER_PLAN.md`. The broken links are in the table of contents and target section headings with punctuation and numbering. The document remains readable, but navigability is degraded and docs quality signals remain noisy.

***

## Requirements

* R1. All currently reported missing TOC anchors in `docs/INFRASTRUCTURE_MASTER_PLAN.md` must resolve after this pass.
* R2. The visible heading text and document structure must remain unchanged.
* R3. The fix must be local to the master plan document and avoid unrelated docs refactors.
* R4. Strict MkDocs build must continue to pass.

***

## Key Technical Decisions

* KTD1. Use explicit heading IDs with Markdown attribute syntax on affected headings instead of changing TOC text, preserving human-readable section titles while making anchors deterministic.
* KTD2. Patch only the headings referenced by current strict-build diagnostics to keep this pass minimal and low-risk.

***

## Implementation Units

### U1. Add explicit IDs to affected master-plan headings

* **Goal:** Make the existing TOC anchor links resolve consistently.
* **Files:** `docs/INFRASTRUCTURE_MASTER_PLAN.md`
* **Actions:** Add explicit `{ #... }` IDs to the five headings whose TOC links are currently unresolved.
* **Patterns:** Keep current heading titles and numbering exactly as-is; only add ID attributes.
* **Test Scenarios:** Verify each previously missing anchor target now exists and links correctly from TOC.
* **Verification:** `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Confirm no docs-runtime regression

* **Goal:** Ensure docs-only changes do not affect compose/runtime integration.
* **Files:** `mkdocs.yml`, `compose/docker-compose.docs.yml`
* **Actions:** Verification-only; no functional changes expected.
* **Test Scenarios:** Compose config check remains successful.
* **Verification:** `docker compose config --quiet`

***

## Risks And Dependencies

* Risk: Mistyped explicit IDs could preserve link breakage while appearing syntactically valid.
* Dependency: MkDocs markdown extension support for heading attributes remains enabled in current config.

***

## Acceptance Examples

* AE1. Given the updated master plan file, when strict MkDocs build runs, then missing-anchor info lines for the five reported TOC links are absent.
* AE2. Given unchanged heading text, when readers use the TOC, then navigation to Modules 1, 4, 6, 10, and Roadmap works.
