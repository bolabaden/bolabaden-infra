# Orchestration Model

bolabaden is building an orchestration story in layers instead of jumping straight from Docker Compose to a full Kubernetes-style control plane.

## The canonical position

bolabaden is **not** trying to:

- stay forever at "manual docker compose on a few hosts"
- adopt Docker Swarm or Mirantis as the platform's long-term control plane
- migrate the stack wholesale to Kubernetes

bolabaden **is** trying to:

- keep **Compose** as the familiar service authoring surface
- keep **Git** as the operational source of truth
- add a lightweight **control layer** for service identity, health, failover, and routing
- grow toward a more intuitive abstraction only where the current model breaks down under multi-node pressure

## Layer 1: Current operating model

Today the repo is fundamentally a **multi-node Docker Compose system** with any-node ingress:

- Cloudflare provides multi-record DNS failover
- Traefik handles L7 routing and health-aware proxying
- each node can serve local traffic or proxy to a peer
- operators still reason in Compose files, repo commits, and node-local services

This is the model described most directly in:

- [README](../README.md)
- `STRATEGY.md`
- [Infrastructure Master Plan](../docs/INFRASTRUCTURE_MASTER_PLAN.md)

The important constraint is that bolabaden does **not** want a heavyweight centralized scheduler just to get resilient routing and failover.

## Layer 2: Near-term control layer

The next layer is a **Constellation-backed coordination system** that closes the gap between "just Compose" and "real multi-node behavior."

This layer introduces or sharpens concepts such as:

- a cluster-visible **service registry** (`services.yaml` in the architectural docs)
- **gossip state** for node and service health
- **Raft-backed leases** for actions that cannot tolerate split-brain
- **persistent routing** that survives local container failure
- **peer pickup** when a node can no longer host a service

This is the part of the strategy that solves the manual synchronization bottleneck without introducing Kubernetes as the answer to every problem.

Primary references:

- [Failover Agent Brainstorm](../docs/brainstorms/20260604-failover-agent-exploration.md)
- [Constellation Agent Architecture](../infra/docs/ARCHITECTURE.md)
- [Constellation Integration Plan](../infra/docs/CONSTELLATION_INTEGRATION.md)

## Layer 3: Future abstraction layer (CUE)

The long-range direction is **CUE**: a higher-level interface that keeps the Compose authoring experience but adds stronger orchestration semantics.

The repo's blueprint describes this as:

- a **Compose soul** - keep the operator-facing authoring surface readable and portable
- a **headless Kubernetes** posture - adopt stronger cluster ideas only where they reduce real operator pain
- a **translation layer** - support richer scheduling, failover, and policy behavior without forcing the whole repo into handwritten Kubernetes YAML

That future state matters because it explains why the docs talk about:

- `x-cue` spec extensions
- cluster-aware bootstrap
- service identity and health beyond one host
- concept mapping between Compose and Kubernetes-like behavior

But it is still a **future abstraction target**, not a statement that the current repo already exposes a full Kube-compatible control plane.

## Why not just stop at Compose?

The repo's architecture docs repeatedly surface the same failure modes:

- manual secret and env drift across nodes
- failover logic that disappears when local containers stop
- DNS and routing conflicts during node loss
- operational overhead from managing several "almost coordinated" hosts by hand

That is why the platform needs more than plain Compose, but less than a heavyweight orchestrator.

## Why not just switch to Swarm or Kubernetes?

The repo's position is not "those tools are useless." It is:

- **Swarm/Mirantis** brings some useful service and failover concepts, but does not define the future direction here
- **Kubernetes** solves classes of clustering problems, but brings a control-plane and operational cost the repo is explicitly trying to avoid
- bolabaden wants a **selective unification** of the concepts that matter, using tooling and abstractions that fit the homelab / small-infra operator problem better

## Operator mental model

If you need a single sentence mental model:

> bolabaden is building a Compose-first, Git-centered, agent-assisted coordination layer that borrows selected ideas from Swarm and Kubernetes without adopting either platform as the primary operating model.

## Where to go next

- Read [Concept Mapping](concept-mapping.md) if you want platform-to-platform translation.
- Read [Constellation Control Layer](constellation-control-layer.md) if you want the concrete primitives and maturity boundaries.
