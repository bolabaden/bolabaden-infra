---
title: MkDocs Infra README Link Sanitization LFG Pass Plan
type: fix
status: active
date: 2026-06-03
---

# MkDocs Infra README Link Sanitization LFG Pass Plan

## Summary

Sanitize unresolved relative links in the Constellation docs README so strict MkDocs builds remain clean of avoidable link diagnostics after the child docs boundary migration.

---

## Problem Frame

The current strict MkDocs build succeeds but still reports unresolved relative links in `infra/docs/README.md` (`../` and `../scripts/`). Those links relied on repo-root browsing assumptions and do not map cleanly inside the Knowledgebase boundary. This pass should replace those links with boundary-safe targets so docs quality improves without changing service/runtime behavior.

---

## Requirements

- R1. `infra/docs/README.md` must not contain unresolved relative directory links that produce strict-build diagnostics.
- R2. Any replacement links must resolve to valid documentation targets within the MkDocs docs boundary or to explicit external URLs.
- R3. Existing docs runtime contract (`mkdocs.yml` entrypoint, docs compose service, loopback bind, Traefik labels) must remain unchanged.
- R4. Strict MkDocs build must still succeed after the link updates.

---

## Key Technical Decisions

- KTD1. Favor explicit file or URL links over directory traversal links (`../`, `../scripts/`) because MkDocs link validation and site navigation are page-oriented.
- KTD2. Keep this pass scoped to link sanitization in `infra/docs/README.md` to avoid collateral edits in broader docs trees.

---

## Implementation Units

### U1. Replace unresolved infra README relative links with boundary-safe targets

- **Goal:** Eliminate `infra/docs/README.md` links that cannot resolve under MkDocs.
- **Files:** `infra/docs/README.md`
- **Actions:** Replace unresolved directory-style links with concrete page links and/or explicit repository URLs that remain valid in rendered docs.
- **Patterns:** Match existing markdown style in `infra/docs/README.md`; keep link intent (overview + source access + script access) while making targets resolvable.
- **Test Scenarios:** Ensure each updated link target exists and renders as a valid href in the generated site.
- **Verification:** `docker run --rm -v "$PWD:/docs" -w /docs squidfunk/mkdocs-material:latest build -f mkdocs.yml --strict`

### U2. Re-validate docs and compose parity

- **Goal:** Confirm link sanitization does not regress docs runtime integration.
- **Files:** `mkdocs.yml`, `compose/docker-compose.docs.yml`
- **Actions:** No functional changes expected; verification-only check for parity.
- **Test Scenarios:** Strict build remains successful; compose config remains valid.
- **Verification:** `docker compose config --quiet`

---

## Risks And Dependencies

- Risk: Replacing directory links with overly specific paths could reduce usefulness if file locations move in the future.
- Dependency: `squidfunk/mkdocs-material:latest` must remain available for strict-build verification.

---

## Acceptance Examples

- AE1. Given the updated `infra/docs/README.md`, when strict MkDocs build runs, then the previous unresolved relative-link diagnostics for `../` and `../scripts/` are absent.
- AE2. Given no runtime config edits, when compose config is rendered, then docs service behavior remains unchanged.