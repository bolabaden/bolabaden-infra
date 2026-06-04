# Orchestration Overview

This section explains how bolabaden approaches orchestration without adopting a heavyweight control plane.

The short version:

- **Today:** the platform is still **Compose-first** and **Git-centered**.
- **Next:** Constellation adds a lightweight coordination layer for health, routing, leases, and failover.
- **Later:** CUE becomes the higher-level abstraction that keeps Compose as the authoring surface while adding stronger cluster behavior where it matters.

## Read this section in order

1. [Orchestration Model](orchestration-model.md) - the canonical current-state, near-term, and future-state narrative
2. [Concept Mapping](concept-mapping.md) - how bolabaden concepts relate to Compose, Swarm/Mirantis, and Kubernetes
3. [Constellation Control Layer](constellation-control-layer.md) - the concrete control primitives already in `infra/` and the boundaries they still have

## What this section is for

Use this section when you need to answer any of these questions:

- "Are we trying to become Kubernetes?"
- "How is this different from just running Docker Compose on a few VPSs?"
- "Where do service registry, leases, failover, and peer pickup fit?"
- "What is CUE supposed to unify?"

## Primary source documents

- `STRATEGY.md`
- [Infrastructure Master Plan](../docs/INFRASTRUCTURE_MASTER_PLAN.md)
- [Multi-Node Philosophy](../plan-infrastructure-unification.md)
- [Failover Agent Brainstorm](../docs/brainstorms/20260604-failover-agent-exploration.md)
- [Constellation Unified Engine Blueprint](../UNIFIED_ORCHESTRATION_BLUEPRINT.md)

## Boundary

This section documents the intended model. It does **not** claim that every future CUE capability already exists in the current Go implementation.
