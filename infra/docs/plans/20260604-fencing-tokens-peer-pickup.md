# Implementation Plan: Fencing Tokens & Peer Pickup for Failover Agent

## Overview

This plan outlines the technical steps to implement **Fencing Tokens** and **Peer Pickup** logic in the Constellation Agent. These mechanisms are critical for preventing "Split-Brain" scenarios during service migration and failover in a distributed, multi-node environment without a central orchestrator.

## Phase 1: Distributed Fencing Token Mechanism (Raft-Based)

### Goal: Establish a cluster-wide locking system for services

* \[ ] **1.1: Raft FSM Enhancement**
  * File: `infra/cluster/raft/fsm.go`
  * Logic: Add `LeaseTypeService` constant. Update FSM to handle service-scoped leases.
  * Token: The fencing token will be the concatenation of `RaftTerm:LeaseID`.

* \[ ] **1.2: Lease Manager Extensions**
  * File: `infra/cluster/raft/leases.go`
  * Logic: Implement `AcquireServiceLease(serviceName string)` and `RenewServiceLease`.
  * Note: Service leases should be persistent enough to handle short-term node flapping.

* \[ ] **1.3: Integration with Gossip State**
  * File: `infra/cluster/gossip/state.go`
  * Logic: Add `CurrentLease` field to `ServiceHealth` or `NodeMetadata` to allow quick read-only checks of who "owns" a service.

## Phase 2: Secure Migration Protocol (Fencing Integration)

### Goal: Ensure only one node can execute a service at a time

* \[ ] **2.1: Migration Data Model Update**
  * File: `infra/failover/migration.go`
  * Logic: Add `FencingToken string` to the `Migration` and `MigrationRule` structs.

* \[ ] **2.2: Pre-Acquire Lease in Migration**
  * File: `infra/failover/migration.go`
  * Logic: In `executeMigration`, the target node MUST acquire the Raft lease for the service before starting the container on the target node.
  * Enforcement: If a lease acquisition fails (because it's already held and valid), the migration must abort or wait.

* \[ ] **2.3: Adaptive Fencing (Local Shutdown)**
  * File: `infra/cmd/agent/main.go`
  * Logic: Add a background "Lease Watcher" that monitors service leases. If a node discovers it no longer holds the lease for a running service (meaning a peer picked it up), it must forcefully stop the local container.

## Phase 3: Peer Pickup (Failure Escalation Logic)

### Goal: Enable autonomous recovery when a node is completely lost

* \[ ] **3.1: Cluster-Wide Service Monitoring**
  * File: `infra/failover/migration.go`
  * Logic: Update `MonitorAndMigrate` to not only monitor local services but also services assigned to peers that are currently marked as "Dead" OR "Unhealthy" in Gossip.

* \[ ] **3.2: First-Available Pickup Coordination**
  * File: `infra/failover/migration.go`
  * Logic: Use Raft to coordinate which peer picks up a service. The first peer to successfully `AcquireServiceLease` for the dead node's service is designated as the new primary.

## Phase 4: Validation & Hardening

* \[ ] **4.1: Unit Tests for Fencing**
  * Test concurrent acquisition attempts.
  * Test token monotonicity.

* \[ ] **4.2: Chaos Simulation**
  * Simulate node isolation (network partition).
  * Verify that the isolated node stops its services once it realizes it's fenced out.

## Implementation Units (Work Packages)

* **Unit 1**: Raft & Lease Infrastructure (`infra/cluster/raft/`)
* **Unit 2**: Migration Manager Refactor (`infra/failover/`)
* **Unit 3**: Agent Loop & Integration (`infra/cmd/agent/`)
* **Unit 4**: CLI/Dashboard Visibility (Update `api/server.go`)
