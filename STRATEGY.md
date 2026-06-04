***

name: bolabaden.org Infrastructure
last\_updated: 2026-06-04
-------------------------

# bolabaden.org Infrastructure Strategy

## Target problem

Self-hosting operators want multi-node reliability and automated self-healing for web and media services without the complexity of Kubernetes or Swarm. The hard part is overcoming the "manual synchronization" bottleneck—keeping routing, service placement, secrets, and failover behavior consistent and automated across nodes so any node can independently resolve and serve requests.

## Our approach

We run a no-orchestrator, Git-centered architecture where each node shares the same automated edge capabilities, uses lightweight service-discovery state, and supports automated failover and re-deployment. We win by making operations idempotent, self-healing, and horizontally scalable so reliability improves through simple, automated workflows rather than manual control-plane complexity.

## Who it's for

**Primary:** Multi-node homelab and small infra operators - They're hiring bolabaden.org Infrastructure to run resilient self-hosted services across several VPS nodes with predictable operations and minimal orchestration overhead.

## Key metrics

* **Automated recovery success rate** - Percent of service or node failures that are automatically detected and repaired without manual operator intervention; measured via health-check and auto-restart logs.
* **Successful request continuity under node loss** - Percent of routed requests that still succeed during a simulated single-node failure; measured with synthetic checks and proxy logs.
* **Service recovery time after failure** - Time from container/node failure detection to healthy traffic restoration for impacted services; measured from health-check and deployment logs.
* **Configuration convergence time** - Time for service registry/config/secret updates to propagate and become active on all nodes; measured from git-sync and proxy reload timestamps.
* **Template onboarding time** - Time for a new operator/node to reach a healthy baseline deployment using the unified bootstrap flow; measured during onboarding runs.

## Tracks

### Automation and self-healing infrastructure

Harden automated secret/env sync, service failover, and auto-redeploy capabilities (Modules 1, 2, 4, 9) to eliminate manual synchronization bottlenecks.

*Why it serves the approach:* Automation is the core mechanism that delivers high availability and self-healing without introducing a heavy orchestrator.

### Scalable networking and HA service mesh

Optimize Headscale HA leader election, Cloudflare DDNS load balancing, and internal Tailscale DNS (Modules 3, 5, 8) for horizontal scalability and persistent routing.

*Why it serves the approach:* A scalable network layer ensures nodes can independently resolve and proxy traffic to peers reliably.

### Routing, ACLs, and access control

Refine DNS routing patterns, ACLs, Traefik catchall routers, and authenticated rate limiting (Modules 6, 7, 10) to secure the distributed ingress.

*Why it serves the approach:* Secure and deterministic routing is required for a predictable "any-node" ingress model.

### Operability and platform packaging

Expand monitoring, unified bootstrap flows, and templating (Modules 11, 15, 16) so the platform is easy to reproduce and maintain.

*Why it serves the approach:* Idempotent operations depend on low-friction onboarding and a clear, observable operational state.

***

Detailed technical specs for all referenced modules (1-16) live in the [Infrastructure Master Plan](docs/INFRASTRUCTURE_MASTER_PLAN.md).

## Milestones

* **2026-06-30** - Validate multi-node failover and sync workflows with repeatable test evidence across representative services.
* **2026-09-30** - Publish a hardened template path that brings a fresh node/domain to healthy baseline with minimal manual intervention.

## Not working on

* Migrating the platform to Kubernetes or Docker Swarm.
* Building a heavyweight centralized control plane before lightweight sync/failover paths are fully mature.

## Marketing

**One-liner:** High-availability self-hosting across multiple nodes, without Kubernetes complexity.

**Key message:** bolabaden.org Infrastructure prioritizes practical reliability: any-node ingress, peer failover, and Git-driven operations with strong observability. The stack is designed to be copied and adapted, not hand-tuned forever.
