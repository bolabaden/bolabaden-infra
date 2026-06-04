# MkDocs Explicit Excludes + Compose Parity LFG Pass Plan

## Problem

The current MkDocs setup uses `docs_dir: .` with exclusion rules that still include fragile wildcard usage (for example `chart*/**`) and can be tightened to explicit repository paths. In parallel, the Knowledgebase residual checklist in `README.md` has mixed task-list formatting and needs normalization while preserving currently tracked MkDocs residual items. This pass must also keep docs service runtime behavior unchanged (loopback local bind plus Traefik routing) and validate strict build plus compose config commands.

## Scope

In scope:

* Tighten `mkdocs.yml` exclusion entries to explicit repo paths and remove fragile path globs.
* Preserve current docs compose behavior in `compose/docker-compose.docs.yml` (loopback bind and Traefik routing contract).
* Normalize `README.md` Knowledgebase residual checklist formatting and retain tracked MkDocs residual items.
* Validate strict docs build and compose configuration commands used for operational checks.

Out of scope:

* Changing docs hostnames, Traefik routing intent, or local bind port.
* Broad documentation rewrites outside the Knowledgebase residual block.
* Any changes outside the plan-defined files.

## Requirements

* R1: `mkdocs.yml` `exclude_docs` entries must use explicit repo-relative paths for tracked top-level trees and remove fragile wildcard path matching.
* R2: `compose/docker-compose.docs.yml` must keep loopback-only local publish at `127.0.0.1:8001:8000`.
* R3: Traefik routing and service labels for `mkdocs` in `compose/docker-compose.docs.yml` must remain functionally unchanged.
* R4: `README.md` Knowledgebase residual checklist must be normalized to consistent Markdown task-list formatting.
* R5: `README.md` must include the currently tracked MkDocs residual items for loopback-binding acceptance follow-up (`issues/32`) and strict-scope hardening follow-up (`issues/35`).
* R6: Strict build and compose config validation commands must be executable and documented consistently.

## Implementation Units

### U1: Tighten MkDocs exclude patterns to explicit repo paths

Files:

* `mkdocs.yml`

Actions:

* Replace fragile wildcard exclusion patterns with explicit repo-relative path entries.
* Keep exclusion intent aligned to known non-doc trees while preserving existing doc surfaces.

Verification commands:

* `rg -n "exclude_docs|chart\*/\*\*" mkdocs.yml`
* `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2: Preserve docs compose behavior (loopback bind + Traefik routing)

Files:

* `compose/docker-compose.docs.yml`
* `docker-compose.yml`

Actions:

* Keep local publish as loopback-only (`127.0.0.1:8001:8000`).
* Preserve existing Traefik router/service labels and healthcheck behavior for `mkdocs`.
* Ensure compose overlay wiring remains valid in merged config output.

Verification commands:

* `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config --quiet`
* `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config | rg -n "127.0.0.1:8001:8000|traefik.http.routers.mkdocs.rule|traefik.http.services.mkdocs.loadbalancer.server.port|traefik.http.services.mkdocs.loadbalancer.healthcheck.path"`

### U3: Normalize README Knowledgebase residual checklist and retain MkDocs residuals

Files:

* `README.md`
* `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`

Actions:

* Normalize the `### PR Residual` checklist bullet style to a single Markdown task-list format.
* Preserve residual continuity and ensure MkDocs-specific tracked items remain present (issue `32` from the current Knowledgebase checklist and issue `35` from `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`).
* Keep non-MkDocs residual items intact unless formatting-only normalization is required.

Verification commands:

* `rg -n "### PR Residual|issues/32|issues/35" README.md`
* `rg -n "issues/35|Strict MkDocs gate can fail" docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md`
* `rg -n "^[-*] \\[ \\]" README.md`

### U4: Validate strict build and compose config command set

Files:

* `README.md`
* `mkdocs.yml`
* `compose/docker-compose.docs.yml`

Actions:

* Confirm documented compose validation command(s) and strict MkDocs build command execute as expected.
* Keep command forms aligned between docs instructions and actual repo behavior.

Verification commands:

* `docker compose config --quiet`
* `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config --quiet`
* `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

## Test Scenarios

* T1: Exclude pattern hardening
  * Run strict build after exclusion updates and verify no unintended markdown ingestion from excluded non-doc trees.
* T2: Compose behavior parity
  * Render merged compose config and verify loopback bind plus Traefik mkdocs routing labels are unchanged.
* T3: Residual checklist normalization
  * Verify Knowledgebase residual list format is consistent and includes tracked MkDocs follow-ups (`issues/32` and `issues/35`).
* T4: Command validation
  * Execute strict build and compose config commands and confirm successful completion.

## Risks

* Over-tightening exclusion patterns may hide intended markdown sources from nav resolution.
* Compose config may validate while runtime behavior still depends on external environment/labels not covered in this pass.
* Checklist normalization can accidentally drop an existing residual item if edits are not line-by-line verified.
* `docker compose config --quiet` can fail in environments missing required secrets/env files even when docs-specific changes are correct.

## Dependencies

* Docker daemon and Docker Compose CLI are installed and usable.
* `squidfunk/mkdocs-material:latest` image is pullable/runnable for strict validation.
* Existing docs service definition remains in `compose/docker-compose.docs.yml` and is included by `docker-compose.yml`.
* Required compose environment variables/secrets are available for config rendering in this workspace.
* Existing MkDocs residual tracker remains at `docs/residual-review-findings/feat-mkdocs-knowledgebase-hardening.md` for issue continuity.
