# MkDocs Root Scan Robustness LFG Pass Plan

## Problem

`mkdocs.yml` currently sets `docs_dir: .`, which makes strict builds and live serving scan from repo root. This can pull in non-doc trees and create fragile behavior (unexpected markdown ingestion, noisy strict failures, and accidental coupling to unrelated folders). The pass must harden docs build scope while preserving current docs runtime behavior: loopback-only local publish (`127.0.0.1:8001:8000`) and Traefik host routing for `docs.$DOMAIN`.

## Scope

In scope:

* Constrain MkDocs discovery so documentation content is sourced only from intended docs surfaces, not arbitrary repo trees.
* Preserve docs service behavior in `compose/docker-compose.docs.yml` (loopback host publish plus Traefik routing/health labels).
* Keep runbook references and PR residual tracking aligned with the selected hardening changes.

Out of scope:

* Refactoring unrelated compose stacks.
* Rewriting all historical documentation content.
* Altering Cloudflare/DNS policy beyond existing Traefik host usage.

## Requirements

* R1: Strict MkDocs behavior must not depend on scanning repo root as a docs source.
* R2: Documentation source boundaries must be explicit and implementation-maintainable (no implicit non-doc tree inclusion).
* R3: `compose/docker-compose.docs.yml` must retain loopback-only host publishing (`127.0.0.1:8001:8000`) for local access.
* R4: Existing Traefik docs routing labels and backend health behavior must remain functionally equivalent.
* R5: Runbook references in `README.md` and `docs/index.md` must remain consistent with actual docs startup/access paths.
* R6: PR residual tracking remains durable and current in `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`.
* R7: Verification commands must prove both strict-build robustness and unchanged docs runtime behavior.

## Implementation Units

* U1: Define non-root MkDocs content boundary
  * Files:
    * `mkdocs.yml`
    * `docs/index.md`
  * Actions:
    * Replace repo-root docs scanning strategy with explicit docs-surface mapping.
    * Ensure nav entries continue to resolve using repo-relative paths after boundary change.
    * Keep home and section navigation intact while excluding unrelated repository trees.
  * Verification commands:
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest serve --dev-addr=0.0.0.0:8000 -f mkdocs.yml`

* U2: Preserve docs service loopback and Traefik behavior
  * Files:
    * `compose/docker-compose.docs.yml`
    * `docker-compose.yml`
  * Actions:
    * Confirm docs service port remains loopback-bound (`127.0.0.1:8001:8000`).
    * Keep Traefik router/service labels and healthcheck behavior equivalent to current runtime contract.
    * Validate compose include wiring remains intact.
  * Verification commands:
    * `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config --quiet`
    * `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config | rg -n "mkdocs|127.0.0.1:8001:8000|traefik.http.routers.mkdocs|traefik.http.services.mkdocs"`
    * `docker compose up -d mkdocs && docker ps --filter "name=mkdocs" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"`

* U3: Align runbook and residual tracking with hardened behavior
  * Files:
    * `README.md`
    * `docs/index.md`
    * `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`
  * Actions:
    * Synchronize docs startup/access instructions with hardened MkDocs boundary and current loopback-plus-Traefik routing model.
    * Ensure references to strict validation commands are consistent across runbook entry points.
    * Update residual findings status language so open/closed items match post-change reality without dropping tracker continuity.
  * Verification commands:
    * `rg -n "mkdocs|docs\.\$DOMAIN|localhost:8001|--strict" README.md docs/index.md`
    * `rg -n "Residual Review Findings|mkdocs|compose/docker-compose.docs.yml" docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`
    * `git diff -- README.md docs/index.md docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`

## Test Scenarios

* T1: Strict build isolation
  * Run strict build and verify no failures from unrelated non-doc tree markdown files.

* T2: Live serve behavior parity
  * Run MkDocs serve command and confirm docs site renders expected navigation after boundary change.

* T3: Compose/runtime parity
  * Render merged compose config and verify loopback publish plus Traefik labels remain present.

* T4: Route access checks
  * Confirm local access via `http://localhost:8001` and routed access intent via `https://docs.$DOMAIN` remain documented and testable.

* T5: Residual/runbook consistency
  * Validate runbook references and residual tracker text describe the same current behavior and remaining follow-ups.

## Risks

* Tightening docs boundaries can break nav targets if referenced files are not explicitly included.
* Hidden reliance on repo-root scanning may surface as missing pages during strict build.
* Label parity checks can pass config rendering while runtime routing still regresses if rule precedence changes elsewhere.
* Residual tracking can drift if issue status text is updated without matching runbook guidance.

## Dependencies

* `mkdocs.yml` exists and remains the single MkDocs config entrypoint.
* Docs service compose overlay remains in `compose/docker-compose.docs.yml` and included by `docker-compose.yml`.
* Docker engine and Docker Compose are available for config and runtime verification.
* `squidfunk/mkdocs-material:latest` image is available for strict build/serve checks.
* Residual tracker file exists at `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`.
