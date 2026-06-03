## Residual Review Findings

- P1 - compose/docker-compose.docs.yml:24 - Docs service local port is published on all interfaces, contradicting localhost-only guidance and bypassing routed TLS path. Tracker: https://github.com/bolabaden/bolabaden-infra/issues/32
- P2 - docker-compose.yml:168 - Chat analytics Kuma labels use malformed variable interpolation, resulting in incorrect monitor names and URLs. Tracker: https://github.com/bolabaden/bolabaden-infra/issues/33
- P1 - mkdocs.yml:4 - Strict MkDocs gate can fail when repo-root docs scanning ingests unrelated non-doc trees. Tracker: https://github.com/bolabaden/bolabaden-infra/issues/35

### Source Context

- Pipeline: /compound-engineering:lfg continue
- Review mode: agent
- Plan: docs/plans/20260603-mkdocs-knowledgebase-hardening-plan.md
- Review summary: Actionable findings 5 across reruns; downstream-resolver residuals 3 (filed)
- Run date: 2026-06-03
