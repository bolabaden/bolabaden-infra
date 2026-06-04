# Concept Mapping

This page translates familiar orchestration concepts into bolabaden's current and planned equivalents.

The goal is orientation, not one-to-one feature parity.

## Comparison at a glance

| Concept | Compose | Swarm / Mirantis | Kubernetes | bolabaden today | bolabaden direction |
|---|---|---|---|---|---|
| **Authoring surface** | `docker-compose.yml` | Compose stack / service specs | YAML manifests / Helm / controllers | Compose files in repo | Compose plus `x-cue` extensions |
| **Source of truth** | local files per host | manager state | API server / etcd | Git repo + per-node runtime state | Git + lightweight distributed coordination |
| **Service identity** | service name on one host | replicated service | Service / Deployment / StatefulSet | service labels + routing patterns | service registry plus cluster-visible service identity |
| **Placement** | manual host choice | scheduler decides nodes | scheduler decides nodes | manual node assignment | preferred-node and peer-pickup logic rather than a general scheduler |
| **Health routing** | container health on one host | service health across swarm | probes + services + ingress | Traefik + local checks + DNS-level failover | gossip-fed health, richer cluster signals, and more durable routing decisions |
| **Failover** | manual or external tooling | manager reschedules tasks | controllers reschedule pods | DNS failover + manual operator-driven service recovery | lease-backed service pickup and migration coordination |
| **Strong coordination** | none | manager quorum | control plane consensus | no cluster-wide coordination guarantee today | Raft-backed lease decisions where anti-split-brain coordination is needed |
| **Desired state** | mostly imperative host state | service replicas/state | declarative reconciliation loop | current state plus automation helpers | selective declarative behavior, not full general reconciliation |
| **Secrets** | files / env / secrets mounts | swarm secrets | Secret objects | secret files and env management | stronger sync / derivation and CUE-oriented secret handling |
| **Ingress** | host ports / reverse proxy | routing mesh / LB | ingress / gateway API | Traefik with any-node ingress | durable cluster-aware routing generation |

## What bolabaden keeps from Compose

bolabaden keeps Compose because it is still the clearest operator-facing declaration of:

- what services exist
- how they are wired
- what images, labels, volumes, and healthchecks they need

That is why the long-range abstraction material keeps returning to **Compose compatibility** instead of requiring a hard pivot to handwritten Kubernetes manifests.

## What bolabaden borrows from Swarm / Mirantis

The useful ideas are mostly around **service-level thinking**:

- service identity above a single container
- health-aware traffic shifting
- multi-node failover expectations
- a more operator-friendly model than raw host-by-host Compose commands

The repo does **not** currently position Swarm or Mirantis as the platform to adopt. They matter here as part of the comparison language and as proof that Compose-adjacent orchestration concepts are legitimate.

## What bolabaden borrows from Kubernetes

The repo borrows selected **control-plane concepts**, not the whole platform:

- stronger service identity
- richer health and readiness semantics
- policy / extension surfaces
- safer coordination for cluster-wide actions
- a path toward declarative intent where it reduces operator toil

The repo does **not** currently claim:

- a full Kubernetes API in production
- a generic scheduler that can place arbitrary workloads anywhere
- complete parity with Deployments, StatefulSets, or controller-manager behavior

## Intentional non-equivalents

Some concepts should stay explicitly non-equivalent:

### Full scheduler

bolabaden is not trying to become a generic bin-packing scheduler. The direction is closer to:

- preferred node placement
- explicit service identity
- peer pickup when a node fails
- enough coordination to avoid split-brain and dead routes

### Centralized control plane

The repo's strategy rejects a heavyweight always-on control plane as the foundation. That means the platform should be described as **agent-assisted coordination**, not as a strict analogue of the Kubernetes API server plus controller-manager stack.

### General declarative reconciliation

The future direction does introduce more declarative behavior, but the current and near-term posture is still selective. The docs should not imply a fully general desired-state loop for every resource the way Kubernetes does.

## The important bridge term: service registry

In the orchestration docs, `services.yaml` is the architectural bridge between today's Compose files and tomorrow's stronger service identity layer.

It means:

- where a service is expected to run
- where a proxy should route
- which node is preferred or currently active

It does **not** mean the internal Go service-provider registry in `infra/config/service_registry.go`.

## How to read future CUE docs

When you see CUE material describing things like `x-cue`, bootstrap phases, or cluster-wide service intelligence, interpret them as:

- a portable abstraction direction
- a vocabulary for future operator experience
- a bridge for unifying the current platform's best ideas

Do **not** interpret them as proof that the current repo already ships a full orchestrator.
