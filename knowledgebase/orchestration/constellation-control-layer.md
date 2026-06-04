# Constellation Control Layer

Constellation is the control layer that explains how bolabaden can stay Compose-first while still adding real multi-node coordination.

## What this layer does

In practical terms, the control layer is responsible for:

- discovering peers
- sharing health information
- coordinating cluster-wide actions that cannot tolerate split-brain
- generating durable routing state from cluster knowledge instead of one host's local Docker view
- supporting service failover and peer pickup as the repo hardens that path

## The main primitives

### Gossip state

Constellation uses gossip to spread cluster knowledge:

- node metadata
- service health
- WARP health

This gives every node a local view of the cluster without introducing a central registry that all reads must go through.

Primary references:

- `infra/cluster/gossip/state.go`
- `infra/docs/ARCHITECTURE.md`
- `infra/docs/COMPONENTS.md`

### Raft-backed leases

Some actions need stronger guarantees than gossip can provide. The repo already uses Raft-backed leases for operations such as:

- load-balancer leadership
- DNS-writer ownership

The newer failover direction extends that pattern toward **per-service fencing** so two nodes do not both believe they own the same service after a failure or recovery event.

Primary references:

- `infra/cluster/raft/leases.go`
- `infra/cluster/raft/fsm.go`
- `infra/cluster/raft/consensus.go`

### Traefik provider generation

A major part of the control-layer story is that routing should not disappear just because one host's Docker state changed.

Instead of trusting only the local Docker socket:

- Constellation exposes Traefik provider data from cluster state
- routes can continue to represent healthy remote backends
- failover stays possible even when the local container that previously owned a route has died

This is one of the clearest ways bolabaden moves beyond raw host-local Compose behavior without adopting Kubernetes ingress machinery.

Primary reference:

- `infra/traefik/http_provider.go`

### Migration and peer pickup

The failover direction described in the repo is not "delete a dead route and hope DNS helps." It is moving toward:

- detecting unhealthy or dead service owners
- coordinating which peer is allowed to pick up the service
- using leases/fencing to prevent split-brain
- making routing and service ownership converge on the surviving node

Primary references:

- `docs/brainstorms/20260604-failover-agent-exploration.md`
- `infra/failover/migration.go`

## The `services.yaml` bridge

Architecturally, the repo keeps pointing to a simple distributed `services.yaml` registry as the bridge concept between:

- service definitions in Compose
- routing state in Traefik
- cluster-visible placement and failover intent

That registry matters because it lets the system reason about **service identity** even when local containers die.

Important boundary:

- the architectural `services.yaml` registry is **not** the same thing as `infra/config/service_registry.go`
- the former is a distributed placement/routing concept
- the latter is an internal Go registry for service providers

## Current maturity boundaries

The control-layer story is real, but the maturity line matters:

- Constellation already has concrete gossip, lease, routing, and health-monitoring primitives.
- The failover/migration path exists in code and docs, but some execution paths are still documented as simulated or partial.
- The repo is still evolving the exact service-registry, peer-pickup, secret-distribution, and stateful-failover story.

That means the docs should talk about three categories explicitly:

1. **Implemented primitives** - gossip, selected leases, health state, provider generation
2. **In-progress failover behavior** - migration framework, fencing-token direction, peer pickup
3. **Future abstraction** - CUE as the portable higher-level surface

## Open constraints the docs should keep visible

The control layer does not erase hard distributed-systems problems. The repo already names several:

- **Split brain** - two nodes must not both believe they own a service
- **Secrets distribution** - peer pickup requires the right secret material on the surviving node
- **Stateful workloads** - storage and replication still matter; moving a container is not the same as moving healthy state

These are not footnotes. They are part of the reason the repo wants a careful, incremental coordination layer instead of pretending failover is solved by restarting containers elsewhere.

## Practical mental model

If the platform's current stack is:

- Compose for service definition
- Traefik for ingress
- Cloudflare for node-level DNS failover

then Constellation is the layer that makes those pieces behave more like a coherent multi-node system:

- gossip for awareness
- Raft for the decisions that must be singular
- provider generation for durable routing
- migration and peer-pickup logic for service continuity

## Related reading

- [Orchestration Model](orchestration-model.md)
- [Concept Mapping](concept-mapping.md)
- [Constellation Agent Architecture](../infra/docs/ARCHITECTURE.md)
- [Infrastructure Master Plan](../docs/INFRASTRUCTURE_MASTER_PLAN.md)
- [Failover Agent Brainstorm](../docs/brainstorms/20260604-failover-agent-exploration.md)
