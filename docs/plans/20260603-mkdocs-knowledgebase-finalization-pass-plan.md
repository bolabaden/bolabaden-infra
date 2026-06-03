# MkDocs Knowledgebase Finalization Execution Plan (Pass 2)

## Problem

The MkDocs knowledgebase integration is present and runnable, but this execution pass must harden production behavior and verification discipline in four specific areas: docs service exposure model, strict MkDocs build assumptions, label/link consistency, and persistence of the PR residual handoff section.

## Scope

In scope:

* Validate and finalize docs service exposure in `compose/docker-compose.docs.yml` (loopback-only host publishing vs public host publishing) while preserving Traefik routing.
* Validate `mkdocs.yml` assumptions and enforce a strict build path suitable for repeatable verification.
* Verify cross-file consistency for docs labels, endpoints, and links in `mkdocs.yml`, `docs/index.md`, `README.md`, and `compose/docker-compose.docs.yml`.
* Keep a durable PR residual section in `README.md` that survives this pass and can carry forward unresolved follow-ups.
* Define executable implementation and verification commands.

Out of scope:

* Rewriting non-docs service compose stacks.
* Content rewrites for unrelated markdown documents.
* DNS provider policy changes outside docs routing validation.

## Requirements

* R1: Exposure model in `compose/docker-compose.docs.yml` is explicitly decided and implemented as either loopback-bound host port publish (`127.0.0.1:8001:8000`) or intentional public host publish (`8001:8000`) with rationale documented in `README.md`.
* R2: `mkdocs.yml` builds cleanly with strict checks and no unresolved nav/doc references using a deterministic command path.
* R3: `mkdocs.yml` nav entries and `docs/index.md` quick links remain internally consistent and repo-relative.
* R4: `compose/docker-compose.docs.yml` labels for Traefik and Homepage are validated against documented endpoints in `README.md` and `docs/index.md`.
* R5: A durable `PR Residual` section exists in `README.md` and is updated (not removed) to capture deferred follow-up items from this pass.
* R6: Compose include wiring remains valid from `docker-compose.yml` to `compose/docker-compose.docs.yml` with no config regressions.
* R7: Verification commands are documented and produce clear pass/fail signals for maintainers.

## Implementation Units

* U1: Finalize docs service exposure model
  * Files:
    * `compose/docker-compose.docs.yml`
    * `README.md`
  * Actions:
    * Choose and apply one exposure mode:
      * Loopback-safe mode: `ports: ["127.0.0.1:8001:8000"]`
      * Public mode: `ports: ["8001:8000"]`
    * Preserve Traefik backend at container port `8000` and keep healthcheck unchanged unless required by decision.
    * Document the selected mode, rationale, and operator impact in `README.md` knowledgebase section.
  * Verification commands:
    * `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config --quiet`
    * `docker compose up -d --force-recreate mkdocs`
    * `docker ps --filter "name=mkdocs" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"`

* U2: Enforce strict MkDocs configuration validation
  * Files:
    * `mkdocs.yml`
    * `README.md`
  * Actions:
    * Validate that `docs_dir`, `nav`, and markdown extension assumptions match repository layout.
    * Standardize one strict validation command path and add it to docs runbook text in `README.md`.
  * Verification commands:
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest serve --dev-addr=0.0.0.0:8000 -f mkdocs.yml`

* U3: Validate labels and link consistency
  * Files:
    * `compose/docker-compose.docs.yml`
    * `mkdocs.yml`
    * `docs/index.md`
    * `README.md`
  * Actions:
    * Cross-check endpoint declarations (`https://docs.$DOMAIN`, local host URL) across all four files.
    * Validate Traefik label set (`router rule`, `entrypoints`, `tls`, service port, healthcheck path/interval).
    * Validate Homepage metadata labels (`group`, `name`, `href`, `description`, `icon`) against intended docs UX.
    * Verify top-level internal markdown links from `docs/index.md` and nav targets from `mkdocs.yml`.
  * Verification commands:
    * `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config | rg -n "mkdocs|traefik.http.routers.mkdocs|homepage\."`
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`
    * `rg -n "docs\.\$DOMAIN|localhost:8001|docker compose up -d mkdocs" README.md docs/index.md compose/docker-compose.docs.yml`

* U4: Preserve and update PR residual durability
  * Files:
    * `README.md`
  * Actions:
    * Add or update a dedicated `PR Residual` subsection under the knowledgebase area.
    * Keep unresolved follow-ups as explicit checklist items with owner/action intent (no silent deletion).
    * Ensure future passes can append residual items without rewriting section structure.
  * Verification commands:
    * `rg -n "^## PR Residual|^### PR Residual|\- \[ \]" README.md`
    * `git diff -- README.md | rg -n "PR Residual|Knowledgebase"`

* U5: Re-validate include wiring and end-to-end runbook
  * Files:
    * `docker-compose.yml`
    * `compose/docker-compose.docs.yml`
    * `README.md`
  * Actions:
    * Confirm `docker-compose.yml` include entry for `compose/docker-compose.docs.yml` stays intact.
    * Ensure README runbook commands map exactly to current compose wiring.
  * Verification commands:
    * `rg -n "^include:|compose/docker-compose.docs.yml" docker-compose.yml`
    * `docker compose config --quiet`
    * `docker logs --tail=100 mkdocs`

## Test Scenarios

* T1: Exposure mode behavior test
  * Bring up `mkdocs` and validate host port visibility matches selected model.
  * Command set:
    * `docker compose up -d mkdocs`
    * `ss -tulpen | rg ":8001"`
    * `curl -I http://localhost:8001`

* T2: Strict build regression gate
  * Build docs in strict mode and fail on any broken nav/reference issue.
  * Command:
    * `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

* T3: Label-to-endpoint consistency check
  * Validate Traefik/Homepage labels and README/index endpoint declarations are aligned.
  * Command set:
    * `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config | rg -n "docs\.\$DOMAIN|traefik\.http\.routers\.mkdocs|homepage\.href"`
    * `rg -n "docs\.\$DOMAIN|localhost:8001" README.md docs/index.md`

* T4: PR residual durability test
  * Ensure the PR residual section remains present after edits and includes actionable unchecked items when applicable.
  * Command:
    * `rg -n "PR Residual|\- \[ \]" README.md`

* T5: End-to-end service health and runtime check
  * Confirm service is healthy and logs are clean after final wiring.
  * Command set:
    * `docker ps --filter "name=mkdocs" --format "table {{.Names}}\t{{.Status}}"`
    * `docker inspect mkdocs --format '{{json .State.Health}}'`
    * `docker logs --tail=100 mkdocs`

## Risks

* Choosing public host publishing may unintentionally expose docs outside intended trust boundaries.
* Choosing loopback-only publishing without documenting access path can break operator expectations.
* Strict build enablement can surface latent broken links/nav entries across historical markdown files.
* Label drift between compose and README/docs content can create false operational guidance.
* PR residual section may regress if future cleanup edits remove it as "temporary" text.

## Dependencies

* Docker Engine and Docker Compose available on target environment.
* Repository files present and writable:
  * `mkdocs.yml`
  * `docs/index.md`
  * `README.md`
  * `docker-compose.yml`
  * `compose/docker-compose.docs.yml`
* Runtime environment variables for compose rendering (`DOMAIN`, `TS_HOSTNAME`, and other existing stack vars).
* Access to `squidfunk/mkdocs-material:latest` image for strict build validation.
