---
name: bolabaden.org Infrastructure
last_updated: 2026-06-04
---

# bolabaden.org Infrastructure Strategy

## Target problem

Self-hosting operators want multi-node reliability for web and media services without the operational cost of Kubernetes or Swarm. The hard part is keeping routing, service placement, secrets, and failover behavior consistent across nodes so any request can be served even when it lands on the "wrong" node or a node fails.

## Our approach

We run a no-orchestrator, Git-centered architecture where each node shares the same edge capabilities, uses lightweight service-discovery state, and forwards traffic to healthy peers when needed. We win by making operations idempotent, observable, and template-ready so reliability improves through simple, repeatable workflows instead of control-plane complexity.

## Who it's for

**Primary:** Multi-node homelab and small infra operators - They're hiring bolabaden.org Infrastructure to run resilient self-hosted services across several VPS nodes with predictable operations and minimal orchestration overhead.

## Key metrics

- **Successful request continuity under node loss** - Percent of routed requests that still succeed during a simulated single-node failure; measured with synthetic checks and proxy logs.
- **Service recovery time after failure** - Time from container/node failure detection to healthy traffic restoration for impacted services; measured from health-check and deployment logs.
- **Configuration convergence time** - Time for service registry/config updates to propagate and become active on all nodes; measured from sync events and proxy reload timestamps.
- **Operator intervention rate** - Count of manual incident actions per week for routing, failover, and secret/config drift; measured in ops runbook/incident notes.
- **Template onboarding time** - Time for a new operator/node to reach a healthy baseline deployment using repo bootstrap docs; measured during onboarding runs.

## Tracks

### Distributed routing and failover reliability

Harden L7/L4 forwarding, health checks, and fallback behavior so requests succeed regardless of entry node.

_Why it serves the approach:_ This is the core mechanism that delivers high availability without introducing an orchestrator.

### Sync and state consistency

Improve secret/env/config synchronization and service-discovery propagation so each node reflects current intended runtime state quickly and safely.

_Why it serves the approach:_ A lightweight architecture only works when node state converges reliably after changes.

### Operability and observability

Expand monitoring, diagnostics, and maintenance automation so failures are visible early and recovery is repeatable.

_Why it serves the approach:_ Idempotent operations depend on fast detection, clear signals, and low-friction remediation.

### Reusable platform packaging

Refine documentation, templates, and bootstrap workflows so the stack is easy to reproduce for new domains and teams.

_Why it serves the approach:_ Template readiness is how the same architecture scales beyond one bespoke deployment.

## Milestones

- **2026-06-30** - Validate multi-node failover and sync workflows with repeatable test evidence across representative services.
- **2026-09-30** - Publish a hardened template path that brings a fresh node/domain to healthy baseline with minimal manual intervention.

## Not working on

- Migrating the platform to Kubernetes or Docker Swarm.
- Building a heavyweight centralized control plane before lightweight sync/failover paths are fully mature.

## Marketing

**One-liner:** High-availability self-hosting across multiple nodes, without Kubernetes complexity.

**Key message:** bolabaden.org Infrastructure prioritizes practical reliability: any-node ingress, peer failover, and Git-driven operations with strong observability. The stack is designed to be copied and adapted, not hand-tuned forever.