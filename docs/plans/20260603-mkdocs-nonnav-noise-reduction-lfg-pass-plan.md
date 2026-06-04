***

title: MkDocs Non-Nav Noise Reduction LFG Pass Plan
type: fix
status: active
date: 2026-06-03
----------------

# MkDocs Non-Nav Noise Reduction LFG Pass Plan

## Summary

Reduce strict-build informational noise by explicitly surfacing known operator-facing infra pages in navigation while retaining broad excludes only for non-published plan and residual artifacts.

***

## Problem Frame

Current strict MkDocs builds pass, but previously emitted repeated informational lines listing pages that existed in the docs boundary but were not included in `nav`. The specific files were `infra/README.md`, `infra/CONTRIBUTING.md`, `infra/docs/COMPLETE_REFACTORING_SUMMARY.md`, and `infra/docs/COMPLETION_SUMMARY.md`.

This pass resolves the noise by explicitly surfacing those files in navigation while keeping the intentionally broad excludes for plan and residual artifacts.

***

## Requirements

* R1. `mkdocs.yml` must explicitly surface the currently reported non-nav infra files in navigation.
* R2. Existing nav content and runtime docs service behavior must remain unchanged.
* R3. Strict MkDocs build must continue passing and no longer report the targeted non-nav files in the informational list.
* R4. Compose config validation must remain successful.

***

## Key Technical Decisions

* KTD1. Prefer adding meaningful nav entries for non-sensitive documentation pages over excluding them when they are valid operator-facing content.
* KTD2. Keep broad excludes only for intentionally non-published internal artifacts (`docs/plans/**`, `docs/residual-review-findings/**`), with patterns interpreted relative to `docs_dir: knowledgebase`.
* KTD3. Keep this pass scoped to `mkdocs.yml` and avoid touching documentation content unless validation proves it is necessary.

***

## Implementation Units

### U1. Exclude targeted out-of-nav files in mkdocs config

* **Goal:** Remove recurring non-nav informational entries for known infra files by explicitly surfacing them in nav.
* **Files:** `mkdocs.yml`
* **Actions:** Add nav entries for `infra/README.md`, `infra/CONTRIBUTING.md`, `infra/docs/COMPLETE_REFACTORING_SUMMARY.md`, and `infra/docs/COMPLETION_SUMMARY.md`.
* **Patterns:** Preserve current child-boundary docs model and keep `exclude_docs` restricted to non-published plan/residual artifacts.
* **Test Scenarios:** Strict build output should no longer list the targeted files under the non-nav informational section.
* **Verification:** `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Reconfirm compose/runtime parity

* **Goal:** Ensure docs config-only change does not alter compose/runtime behavior.
* **Files:** `compose/docker-compose.docs.yml`, `docker-compose.yml`
* **Actions:** Verification-only; no edits expected.
* **Test Scenarios:** Compose config continues to validate with current environment.
* **Verification:** `docker compose config --quiet`

***

## Risks And Dependencies

* Risk: Excluding the wrong path could hide documentation that should be in nav.
* Dependency: The docs boundary remains rooted at `knowledgebase` and uses stable relative paths in `mkdocs.yml`.

***

## Acceptance Examples

* AE1. Given the updated `mkdocs.yml`, when strict build runs, then the previously listed targeted non-nav files are no longer reported.
* AE2. Given no runtime-service edits, when compose config runs, then it remains valid with existing environment warnings only.
