***

title: MkDocs Child Docs Boundary LFG Pass Plan
type: fix
status: active
date: 2026-06-03
----------------

# MkDocs Child Docs Boundary LFG Pass Plan

## Summary

Harden the Knowledgebase by removing repo-root MkDocs source scanning and replacing it with an explicit child-directory docs boundary that still serves the same knowledgebase content, preserves the current docs container routing contract, and closes the open issue-35 residual.

***

## Problem Frame

The repo still carries an open residual that `mkdocs.yml` uses `docs_dir: .`, which keeps documentation discovery coupled to the repository root. Even with tightened `exclude_docs` rules, this remains fragile because unrelated markdown trees can still influence strict builds, nav resolution, and future maintenance. The remaining pass needs to make the docs boundary explicit rather than relying on exclusions to simulate one.

***

## Requirements

### Docs Boundary

* R1. MkDocs must stop treating the repository root as the documentation source boundary.
* R2. The new documentation source boundary must be a child directory of the MkDocs config location and be maintainable without relying on repo-wide exclusion lists to model the intended site surface.
* R3. Existing knowledgebase content referenced in navigation must remain reachable after the boundary change, either by relocating source documents into the new boundary or by generating an equivalent docs-facing structure.

### Runtime Parity

* R4. `compose/docker-compose.docs.yml` must retain loopback-only local publishing at `127.0.0.1:8001:8000`.
* R5. Existing Traefik router, service, and healthcheck behavior for the `mkdocs` service must remain functionally unchanged.

### Operator and Residual Alignment

* R6. Runbook guidance in `README.md` and `docs/index.md` must remain accurate for local and routed access after the boundary change.
* R7. Residual tracking in `README.md` and `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md` must be updated so issue `35` reflects the post-change reality without losing tracker continuity.

### Verification

* R8. Strict MkDocs build must succeed against the new configuration without scanning arbitrary repo-root markdown trees.
* R9. Compose validation must continue to succeed for the docs service integration.

***

## Key Technical Decisions

* KTD1. Use a real child docs boundary instead of further expanding `exclude_docs`: this addresses the root cause rather than extending a brittle allow-by-exclusion model.
* KTD2. Keep `mkdocs.yml` as the single entrypoint: operators already use that path in runbooks and the compose service, so the hardening should preserve the config entrypoint while changing the docs source layout behind it.
* KTD3. Preserve runtime behavior separately from content-boundary changes: the docs source fix should not be allowed to widen local exposure or alter routed host behavior.

***

## Implementation Units

### U1. Establish a child-directory MkDocs source boundary

* **Goal:** Replace `docs_dir: .` with a real child-directory docs source and make the knowledgebase nav resolve from that boundary.
* **Files:** `mkdocs.yml`, `docs/`, `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `DOCKER_SECRETS_README.md`, `SECURITY_STATUS.md`, `alt_design.md`, `plan-infrastructure-unification.md`, `infra/docs/`
* **Actions:** Choose a concrete child-directory strategy for the knowledgebase source tree, update `mkdocs.yml` to point at it, and ensure every nav target resolves within the new boundary.
* **Patterns:** Follow the existing knowledgebase information architecture already expressed in `mkdocs.yml`; preserve section naming unless a boundary constraint forces a targeted adjustment.
* **Test Scenarios:** Verify that Home, Getting Started, Architecture, Constellation Agent, High Availability, Operations, KotorModSync Integration, and Contributing sections all resolve after the boundary change.
* **Verification:** `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Preserve docs service runtime contract

* **Goal:** Confirm the docs boundary change does not alter the runtime exposure model.
* **Files:** `compose/docker-compose.docs.yml`, `docker-compose.yml`
* **Actions:** Keep the docs container command, loopback port binding, Traefik labels, and service healthcheck behavior functionally equivalent unless a boundary-path adjustment is required for the container command.
* **Patterns:** Preserve the existing docs service contract instead of redesigning the service definition during this pass.
* **Test Scenarios:** Verify merged compose output still shows the loopback port mapping and mkdocs Traefik labels.
* **Verification:** `docker compose config --quiet`

### U3. Align operator docs and residual tracking

* **Goal:** Keep runbooks and residual state synchronized with the hardened docs boundary.
* **Files:** `README.md`, `docs/index.md`, `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`
* **Actions:** Update documentation only where the boundary change affects commands, assumptions, or residual wording; close or rewrite issue-35 references when the underlying root-scan risk is actually resolved.
* **Patterns:** Preserve the existing Knowledgebase section and residual-review format; make targeted edits instead of broad documentation rewrites.
* **Test Scenarios:** Verify local and routed access instructions remain correct and residual issue references match the new repo state.
* **Verification:** `rg -n "mkdocs|localhost:8001|docs\.\$DOMAIN|issues/35|Residual Review Findings" README.md docs/index.md docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`

***

## Risks And Dependencies

* Risk: Converting root-level markdown references into a child-directory docs tree can break nav links if mirrored paths drift from the actual source files.
* Risk: A generated or duplicated docs tree can introduce maintenance drift if the chosen structure is not obvious to operators.
* Dependency: Docker and `squidfunk/mkdocs-material:latest` must remain available for strict-build validation.
* Dependency: The current docs service include path in `docker-compose.yml` must remain intact.

***

## Acceptance Examples

* AE1. Given the repo on the current branch, when the strict MkDocs build runs, then it succeeds without relying on repo-root markdown discovery.
* AE2. Given the merged compose configuration, when the docs service is rendered, then it still exposes `127.0.0.1:8001:8000` and retains the current mkdocs Traefik labels.
* AE3. Given the updated runbook and residual files, when an operator checks the Knowledgebase section and residual tracker, then issue `35` is either removed or restated to reflect any genuinely remaining post-hardening follow-up.
