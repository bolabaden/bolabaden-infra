# 🚀 CUE Bootstrap Protocol: The "Zero-ENV" Implementation

This document defines the technical logic for the `cue bootstrap` command—a single-binary entry point that transforms a fresh VPS into a fully-configured node in the **Constellation Unified Engine (CUE)** cluster.

## 🎯 The Problem: "Environmental Attrition"

Currently, setting up a new node requires:

1. Manually cloning the repo.
2. Generating 50+ lines of `.env` secrets.
3. Setting up `SECRETS_PATH`.
4. Configuring Tailscale/Headscale auth keys.
5. Manually installing Docker/Traefik.

**The CUE Solution**: A deterministic, state-driven bootstrap process that pulls configuration from the "Seed Node" and self-assembles the environment.

***

## 🛠️ The Bootstrapping Lifecycle

### Phase 1: Identity Discovery (The "First Contact")

When `cue bootstrap` is run, it performs a system audit:

* **Architecture**: Detects CPU (x86\_64 vs ARM64) to select the correct `containerd` and `k3s-engine` binaries.
* **Hardware**: Checks for NVIDIA/Intel GPUs (allocates drivers automatically).
* **Public IP**: Identifies the primary public interface for DNS registration.

### Phase 2: Mesh Integration (The "Nerve System")

CUE assumes every node starts "blind."

1. **Headscale Handshake**: If a Headscale token is provided (or if joining an existing cluster), CUE registers the node in the internal WireGuard mesh.
2. **Virtual Interface Creation**: CUE brings up the `cue0` mesh interface (Tailscale).
3. **Internal Key Exchange**: Generates a local Ed25519 keypair for node-to-node Raft communication.

### Phase 3: The "Infra Hydration" (State Sync)

Once the mesh is alive, CUE connects to the cluster's Kine (SQLite) database.

1. **Global Registry Fetch**: Pulls the current `services.yaml` and global secrets.
2. **Local Schema Provisioning**:
   * Creates `/opt/cue/volumes` for local persistence.
   * Sets up `/run/secrets` as a `tmpfs` (RAM) mount.
3. **System Plane Deployment**: Automatically pulls and starts core system pods (Traefik, Dozzle, Watchtower) if they are designated for this node.
4. **Recursive Spec Application**: CUE executes the `cue up` cycle on the `docker-compose.yml` manifest, applying all `x-cue` extensions (see [knowledgebase/CUE_SPEC_EXTENSIONS.md](knowledgebase/CUE_SPEC_EXTENSIONS.md)) to the local containerd instance.

***

## 🔒 Secret Derivation Logic (Eliminating Manual .env)

CUE moves from **Static Secrets** (stored in files) to **Derived Secrets** (stored in the distributed state engine).

| Secret Type | Current Method | CUE Method |
| :--- | :--- | :--- |
| **Database Passwords** | Manually set in `.env` | **Auto-Generated.** On service creation, CUE generates a secure 32-char string and stores it in the Kube-Secret store. It is injected into the container at runtime. |
| **API Keys** | Manually set in `.env` | **Rotated on Join.** Node-specific API keys are derived from the Cluster Master Key + Node ID, meaning they are unique to each VPS. |
| **Domain Salts** | Hardcoded in scripts | **Cluster-Global Constant.** A single "Seed Secret" is generated at Cluster Birth; all other IDs are HMAC-hashes of this seed. |

***

## 📦 The "Single Artifact" Concept

The CUE binary is shipped as a static binary containing:

* **CUE Engine**: The Go-based controller.
* **Embedded Kine**: The SQLite-to-Kube translator.
* **Embedded Static Assets**: Default configs for Traefik, monitoring, and AI services.
* **Bootstrapper**: The logic to clean `iptables` and prepare the OS.

### Example User Workflow:

```bash
# 1. Download the tool
curl -L cue.bolabaden.org/install.sh | sudo bash

# 2. Join the cluster
cue join --seed https://node1.bolabaden.org --token <cluster-token>

# 3. Everything is done.
# Node is healthy, services are synced, monitoring is active.
```

***

## 🚦 Pre-Flight Safety Checks

To avoid the "Dirty Mesh" problems highlighted in [plan-infrastructure-unification.md](plan-infrastructure-unification.md), the bootstrap command performs:

1. **Port Check**: Verifies 80/443 (HTTP), 6443 (K8s), and 41641 (Headscale) are free.
2. **Disk Check**: Ensures at least 20GB of free space.
3. **Kernel Check**: Verifies `overlay` and `br_netfilter` modules are loaded.
4. **Network Check**: Runs a latency test to the Seed Node. If latency is >200ms, it warns the user of potential gossip timeouts.

***

## 📉 Rollback Capabilities

If bootstrapping fails at any stage:

* `cue reset --hard`: Completely wipes the CUE data directory, flushes iptables, and disconnects from the Tailscale mesh, leaving the VPS in a clean state (avoiding "orphaned router" records).
