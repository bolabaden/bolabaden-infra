# Brainstorm: Module 4 — Service Failover & Auto-Redeploy (Next-Gen)

> **Status**: Phase 1.1 (Exploration)\
> **Date**: 2026-06-04\
> **Topic**: Replacing the broken `docker-gen-failover` with a robust, Go-based `bolabaden-failover-agent` (Constellation integration).

## 1. Diagnosis (The "Why")

### The Failure of `docker-gen`

* **The Bug**: When a container stops/dies, `docker-gen` excludes it from the template context, even with `-include-stopped`. This results in the deletion of the Traefik route, which is the exact opposite of "failover."
* **The Gap**: There is no mechanism to "hand off" a service to a peer node if the local instance stays down.
* **The Constraint**: We MUST maintain the "No Orchestrator" philosophy. No K8s control plane, no Swarm.

## 2. Approach (The "How")

### 2.1 Transition to Constellation

* **Service Registry**: A central `services.yaml` (already conceptually in the Master Plan) that tracks service-to-node mapping.

* **Active Health Checking**: Constellation agents on each node will ping local services via Traefik/HTTP and report status.

* **Desired vs. Actual State (Lightweight)**: Since we are "no-cluster," we don't have a global state, but we can have "Preferred Nodes."

### 2.2 Core Mechanisms

1. **Persistence**: Traefik routes for a service are *never* deleted unless explicitly removed from `services.yaml`.
2. **Weighted Routing**: Traefik `weighted-round-robin` will point to all nodes. Healthy local nodes get weight `100`, remote nodes get weight `1` (or vice versa depending on proxy costs), but health checks in Traefik handle the actual traffic shift.
3. **Auto-Redeploy (The "Hero" Move)**: If Node A goes down and Node B hears about it (or detects it via health check), Node B can run the `docker compose` command for the missing service using the shared Git repo.

## 3. Product Pressure Test (Brainstorming Questions)

* **Q1 (Conflict)**: If Node B starts Node A's service, how do we prevent a "Split Brain" where both eventually run it once Node A recovers?
* **Q2 (Security)**: How does Node B get the secrets to run Node A's service if secrets are local? (Master Plan Module 1: Secret Sync is a hard dependency).
* **Q3 (Storage)**: What happens to persistent data (Volume sync)? (Master Plan Module 11: Meditation Wizard / Storage? No, we need a Module for Rclone/Sync).

## 4. Proposed Solution Canvas (Draft)

* **Component**: `infra/failover/agent.go`
* **Trigger**: Docker Engine API Event `die` or `health_status: unhealthy`.
* **Action**:
  1. Local Restart: `docker compose restart <service>`.
  2. Escalation: If `unhealthy` persists for 3 retries, update `services.yaml` status and "Request Peer Pickup."
  3. Peer Logic: Peers listen on a gossip/Headscale port. First available peer takes a Redis/File lock and starts the container.

***

*This document is the output of Phase 1.1 of the ce-brainstorm workflow.*
