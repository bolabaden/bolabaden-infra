# MkDocs Knowledgebase Integration Hardening Plan

## Problem

The repository already contains initial MkDocs integration files, but the knowledgebase pipeline is not yet fully hardened end-to-end. We need a concrete completion plan that validates compose integration, link integrity, runtime startup flow, and service discovery labels so the docs site is reliable in local and multi-node environments.

## Scope

In scope:
- Finish and harden MkDocs integration around existing files: `mkdocs.yml`, `docs/index.md`, and `compose/docker-compose.docs.yml`.
- Validate compose rendering and service startup behavior.
- Verify local/bare markdown link behavior and document startup commands.
- Verify homepage and Traefik label correctness for docs routing.

Out of scope:
- Refactoring unrelated compose stacks.
- Rewriting content for all existing docs pages.
- Production DNS or Cloudflare policy changes beyond docs service routing checks.

## Requirements

- R1: Keep existing MkDocs entrypoints and repo-relative navigation functional without introducing absolute-path coupling.
- R2: Compose docs service must validate cleanly with project compose overlays and required env inputs.
- R3: Local and bare markdown links must resolve correctly in built/served MkDocs output (no broken internal navigation from core landing docs).
- R4: Service startup command documentation must be complete for local dev and standard stack invocation.
- R5: Homepage labels for the docs service must be present, accurate, and discoverable.
- R6: Traefik labels for docs routing and backend health checks must be correct and testable.
- R7: Verification steps must be executable by maintainers and suitable for CI/manual runbook use.

## Implementation Units

- U1: MkDocs navigation and structure consistency hardening
  - Files:
    - `mkdocs.yml`
    - `docs/index.md`
  - Work:
    - Verify `nav` targets remain valid and consistently repo-relative.
    - Confirm `docs_dir`/path expectations and index references align with actual repository layout.
    - Flag mismatches for correction in subsequent implementation phase.
  - Verification:
    - `mkdocs build -f mkdocs.yml --strict` succeeds.
    - No warnings for missing nav targets or unresolved document references.

- U2: Compose integration validation for docs service
  - Files:
    - `compose/docker-compose.docs.yml`
    - `docker-compose.yml`
  - Work:
    - Validate docs service merge behavior with base compose file.
    - Confirm `publicnet` attachment and container runtime assumptions are correct.
    - Confirm healthcheck and restart semantics match infra conventions.
  - Verification:
    - `docker compose -f docker-compose.yml -f compose/docker-compose.docs.yml config --quiet` succeeds.
    - Rendered compose contains expected `mkdocs` service labels and healthcheck.

- U3: Local and bare links check coverage
  - Files:
    - `docs/index.md`
    - `docs/**/*.md` (spot-check critical entry docs linked from home)
  - Work:
    - Test relative links used by MkDocs navigation and in-page markdown tables.
    - Confirm bare links used in docs content resolve as intended in served site.
    - Produce a checklist of broken link candidates for follow-up fixes.
  - Verification:
    - Link checker run reports zero broken internal links for core landing pages.
    - Manual click-through of top navigation and key quick-navigation links succeeds.

- U4: Service startup command documentation completion
  - Files:
    - `docs/index.md`
    - `README.md`
    - `compose/docker-compose.docs.yml`
  - Work:
    - Document canonical commands for starting docs service alone and with base stack.
    - Document expected endpoints for local (`localhost`) and routed domain access.
    - Document quick troubleshooting commands (compose config, logs, health).
  - Verification:
    - A fresh maintainer can start and access docs service using documented commands only.
    - Command examples align with actual compose files and service names.

- U5: Homepage/Traefik label verification and routing sanity
  - Files:
    - `compose/docker-compose.docs.yml`
  - Work:
    - Validate homepage labels (`group`, `name`, `href`, `description`, `icon`) are consistent and actionable.
    - Validate Traefik router/service label set for docs hostnames and backend port/health check.
    - Confirm labels follow existing repo naming conventions.
  - Verification:
    - Traefik routing rule matches expected docs host patterns.
    - Homepage service card metadata is complete and displays expected destination URL.

## Test Scenarios

- T1: Strict MkDocs build test
  - Run strict build and ensure no unresolved navigation or markdown target errors.

- T2: Compose config synthesis test
  - Render merged compose config and verify docs service appears with expected network, labels, and healthcheck.

- T3: Local service startup test
  - Start docs service via compose overlay and verify HTTP response on local mapped route/workflow.

- T4: Routed host header test
  - Validate Traefik router rule behavior with expected docs hostnames in a representative environment.

- T5: Homepage integration sanity test
  - Confirm homepage metadata points to the docs endpoint and appears in intended group.

- T6: Link integrity test
  - Run automated/manual checks over links exposed from `docs/index.md` and top-level navigation pages.

## Risks

- Relative-path drift between docs content and `mkdocs.yml` navigation can silently break sections.
- Compose environment variable differences across nodes may cause docs route mismatches.
- Traefik rule precedence or host pattern overlap could shadow docs routes.
- Homepage label correctness can pass config checks but still mislead users if URL assumptions are wrong.
- Link checks may miss environment-specific URL behavior unless both local and routed paths are tested.

## Dependencies

- Docker and Docker Compose available in the target environment.
- MkDocs Material image availability (`squidfunk/mkdocs-material:latest`) for runtime validation.
- Required environment variables for compose rendering (including domain-related values used in labels).
- Access to representative Traefik/Homepage runtime for label behavior verification.
- Existing baseline files in this repository:
  - `mkdocs.yml`
  - `docs/index.md`
  - `compose/docker-compose.docs.yml`