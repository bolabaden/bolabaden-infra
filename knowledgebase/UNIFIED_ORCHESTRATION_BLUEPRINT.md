# Constellation Unified Engine (CUE): Strategic Architectural Blueprint

## Multi-Node Container Orchestration Simplified

***

## Executive Summary

The modern container orchestration spectrum is broken. System operators seeking high-availability (HA) deployment patterns are forced into a false, binary choice:

1. **Docker Compose / Swarm**: Simple to configure and operate, but plagued by stagnant development, poor multi-node networking integration, and lack of native support for Kubernetes declarativeness.
2. **Kubernetes (k3s / k8s)**: Out-of-the-box cluster resilience, massive industry support, and a robust declarative API, but gated by a steep operational learning curve, complex network topologies (e.g. CNI overlays, etcd state databases), and complete incompatibility with basic Docker tools (e.g., Dozzle, Watchtower, or traditional `/var/run/docker.sock` integrations).

The attrition of maintaining a distributed, orchestrator-less Docker infrastructure—detailed elegantly in [plan-infrastructure-unification.md](plan-infrastructure-unification.md)—reaches a hard limit of cognitive overload. Key conflicts like dynamic file-generation template failures (the "phantom router"), flat DNS DNS namespace collisions, and un-synchronized secrets drift make horizontal VPS scaling unmaintainable.

This document proposes **Constellation Unified Engine (CUE)**: an open-source, lightweight, single-binary container orchestration system that bridges the gap. Designed as a "headless Kubernetes with a Compose soul," CUE behaves natively like K3s but ingests standard Compose-spec files and emulates a Docker Daemon socket to support existing legacy agents out-of-the-box.

***

## 🏗️ System Architecture & Dual-Engine Parser

Rather than writing a cluster manager from scratch, CUE leverages a hybrid architectural model, combining a **Declarative Kube-API Gateway** with a **Docker Compose Translation Engine** in a single distributed Go binary.

```text
                              ┌────────────────────────────────────────┐
                              │           CUE Command Line             │
                              │       (kubectl / cue-compose)          │
                              └──────────────────┬─────────────────────┘
                                                 │
                                                 ▼
                              ┌────────────────────────────────────────┐
                              │      CUE Control Plane Daemon          │
                              ├────────────────────────────────────────┤
                              │                                        │
                              │  ┌──────────────────────────────────┐  │
                              │  │       Lightweight Kube-API       │  │
                              │  │      Gateway (6443 / Kine)       │  │
                              │  └────────────────┬─────────────────┘  │
                              │                   │                    │
                              │                   ▼                    │
                              │  ┌──────────────────────────────────┐  │
                              │  │    CUE Translation Middleware    │  │
                              │  │  (Compose-Spec <=> K8s Schema)   │  │
                              │  └────────────────┬─────────────────┘  │
                              │                   │                    │
                              │                   ▼                    │
                              │  ┌──────────────────────────────────┐  │
                              │  │    Virtual Docker Unix Socket    │  │
                              │  │     (/var/run/docker.sock)       │  │
                              │  └────────────────┬─────────────────┘  │
                              │                   │                    │
                              └───────────────────┼────────────────────┘
                                                  │
                  ┌───────────────────────────────┴──────────────────────────────┐
                  ▼                                                              ▼
     ┌────────────────────────┐                                     ┌────────────────────────┐
     │      Local Node        │                                     │     Remote Broker      │
     ├────────────────────────┤       Tailscale Encrypted Mesh      ├────────────────────────┤
     │ • Containerd / Podman  │◄───────────────────────────────────►│ • Containerd / Podman  │
     │ • Traefik Ingress      │                                     │ • Tailscale Router     │
     │ • Deunhealth Watchdog  │                                     │ • Local Node Proxies   │
     └────────────────────────┘                                     └────────────────────────┘
```

### 1. The Core Engines

* **The Database Layer (Kine-Backended)**: CUE replaces heavy, distributed `etcd` arrays with Rancher's `kine`, translating the complete Kubernetes API state into a lightweight SQL transaction stream (stored natively in SQLite or a shared PostgreSQL database).
* **The Execution Engine (`containerd` & `podman` Core)**: Rather than running containers via a bloated Docker daemon, CUE interacts directly with the standard `containerd` API via OCI containers, or mimics daemonless execution namespaces using `podman`. This ensures extremely low idle CPU and memory consumption.
* **The State Synchronization Layer**: Utilizing our proven Go-based orchestration primitives from [Constellation Agent Architecture](infra/docs/ARCHITECTURE.md), CUE synchronizes service health and local node capabilities across the server cluster using Gossip protocols (HashiCorp Memberlist) and Raft consensus for atomic updates.

***

## 🌐 Distributed Networking: The Tailscale CNI & Cross-Node Mesh

Conventional Kubernetes requires complex CNI plugins (Calico, Flannel, Cilium) that create heavy overlay networks, often requiring specific MTU configurations and deep kernel hooks. CUE eliminates this by natively integrating **Tailscale (WireGuard)** as its primary backplane.

### 1. The Implicit Overlay (Mesh-by-Default)

Every node joined to a CUE cluster automatically receives a unique internal IP in the `100.64.0.0/10` range. Unlike standard Docker bridge networks which are isolated per host, CUE's virtual network interfaces are globally reachable across the mesh.

### 2. Service-to-Service Anycast

When a Compose service is defined, CUE registers it in the internal cluster DNS (`CoreDNS`).

* **Internal Resolution**: `mongodb.cluster.local` resolves to the Tailscale IPs of all healthy MongoDB pods across the entire cluster.
* **Node-Local Priority**: Traffic defaults to a local pod if one is healthy (minimizing latency). If local pods fail, CUE's distributed router (Traefik) instantly reroutes the request over the encrypted mesh to a peer node.

### 3. Solving the "Phantom Router" & "Hydration Collapse"

As analyzed in [plan-infrastructure-unification.md](plan-infrastructure-unification.md), one of the greatest failures in simple proxy systems is the delay between a container crashing and the router updating.

* **Pre-emptive Failover**: CUE's Traefik ingress doesn't just watch the local Docker socket; it watches the **Global Gossip State**. If a node goes offline, all other nodes are notified within milliseconds via Memberlist.
* **Synthetic Health Signals**: Beyond simple "is the process running?", CUE monitors the **Hydration Status** of frontend services. If a frontend bundle fails to load or returns a 404/500 repeatedly, the agent broadcasts a "Degraded" signal, prompting the ingress layer to bypass that node entirely before the user ever sees a broken page.

***

## 🏗️ The "Unified Fork" Strategy: Reconciling Swarm & K8s

To achieve our goal of being "more unified than Swarm or K3s," CUE implements a hybrid control plane that picks the best features of both worlds:

| Feature | Swarm Approach | K8s Approach | **CUE Unified Method** |
| :--- | :--- | :--- | :--- |
| **Secrets** | Simple tmpfs mounts | Base64 etcd objects | **Native tmpfs + RAM-only sync.** Secrets are never stored unencrypted and are injected into `/run/secrets` via CUE-distributed Gossip. |
| **Scaling** | `replicas: N` | `Replicas: N` | **Node-Aware Scaling.** CUE respects standard Compose `deploy.replicas` but uses K8s-style scheduling algorithms to balance them across the mesh. |
| **Networking** | Overlay Mesh (VIP) | CNI / Ingress | **Tailscale Anycast.** Services get a cluster-wide VIP that routes over the WireGuard mesh. |
| **State** | Shared Folder (Risky) | PVC / CSI | **Local-First CSI.** Automatically handles host-path persistence with node-affinity, ensuring a DB pod always restarts on the node where its data lives. |

### 🚀 Strategic "Clean" Manifests (`x-cue`)

As documented in [CUE Specification Extensions](CUE_SPEC_EXTENSIONS.md), CUE's true power lies in its **Recursive Capability**. We prioritize the work in existing `compose/` files and `docker-compose.yml` by treating them as the **Primary Declarative Manifest**.

Instead of manual K8s YAML or HCL jobs, CUE reads standard Compose files and extracts "Kube-Level" requirements from the `x-cue` extension namespace. This approach bridges the gap that frustrated previous Nomad/K8s attempts:

1.  **Definitions remain human-readable.**
2.  **No manual K8s/Nomad boilerplate is required.**
3.  **The system remains portable.** (Standard Docker just ignores the `x-cue` keys).
4.  **Implicit Hardware Intelligence.** Porting the logic from `infra/services.go`, CUE automatically adds GPU passthrough and transcoding optimizations based on service identity.

***

## 🔌 Compatibility Translation Interfaces

CUE's primary differentiator is **complete dual-compatibility**. Developer processes do not need to change; they interact with the cluster as if it were a standard Kubernetes cloud, a local Docker Compose file, or a classic standalone Docker host.

### 1. Compose-Specification Parser (`cue up -d`)

When standard `docker-compose.yml` configurations are applied to CUE, the built-in parser automatically compiles the YAML elements on-the-fly and generates native, declarative Kubernetes API objects mapping them internally:

| Compose Directive | Target Kubernetes equivalent | CUE Cluster Execution |
| :--- | :--- | :--- |
| `services` | `apps/v1.Deployment` (or `StatefulSet`) | Launches isolated pods with the requested replica scaling, resource flags (`mem_limit`, `mem_reservation`), and restart policies (`always`, `unless-stopped`). |
| `ports` | `v1.Service` + NodePort | Exposes arbitrary ports across the private mesh network, automatically binding routing entry points. |
| `networks` | `networking.k8s.io/v1.NetworkPolicy` | Creates logically isolated network namespaces. Replaces standard flat container networks with secure private virtual subnets. |
| `volumes` | `Local-path-provisioner` (Host Bind) | Mounts direct filesystem bindings (e.g. `/data/db`) dynamically to persistent local directories, tracking geographic node constraints automatically. |
| `secrets` | `v1.Secret` (tmpfs backed) | Mounts securely in-memory under `/run/secrets/` as un-cacheable RAM files, solving the bareenv data exposure loophole. |
| `configs` | `v1.ConfigMap` | Mounts system config files with live reload monitoring. |
| `healthcheck` | `v1.Probe` (Liveness/Readiness) | Translates Compose bash checking scripts into native liveness and readiness container probes handled directly by the engine. |

### 2. Kubernetes API Gateway (`kubectl` Compatible)

CUE exposes a lightweight, fully compliant Kubernetes API listener on port `6443`. To standard clients like `kubectl`, Helm, or Terraform, the cluster appears, registers, and responds as a standard Kubernetes cluster.

When a standard Kubernetes YAML manifest is passed via `kubectl apply -f manifest.yaml`:

1. CUE's API Gateway receives the object.
2. If it is high-level like `Deployment` or `Ingress`, CUE utilizes its internal controller logic to translate these objects into standard container and routing primitives.
3. Because the API matches the K8s Core exactly, the administrator can manage the system with their choice of declarative YAML, CLI tools, or GitOps pipelines.

### 3. Virtual Docker Unix Socket Emulation (`/var/run/docker.sock`)

Many essential self-hosted monitoring and operation services rely on a direct local connection to the Docker Daemon socket. In traditional Kubernetes/K3s installations, these tools completely break: they are missing the Docker socket.

CUE solves this natively by running a **Virtual Docker Socket Daemon Instance** on each node. The daemon intercepts REST calls hitting `/var/run/docker.sock` and translates them dynamically into Kubernetes/Kine API calls:

* **Logging Endpoint (`/containers/<id>/logs`)**: When Dozzle queries the Docker API, CUE's socket proxy catches the request, maps the Docker ID to the local containerd pod ID, and streams the log files directly from the underlying OCI log directory (e.g. `/var/log/pods/`).
* **Inspection `/containers/json`**: Watchtower polls the list of running containers to detect updates to software repositories. CUE maps active Kubernetes Deployments into classic JSON Docker container representations, enabling Watchtower to execute zero-downtime updates safely.
* **Operations `/containers/<id>/restart`**: Deunhealth or general watchdog containers trigger immediate, safe Pod recreations by forwarding container REST requests directly into Kube-API pod deletion commands.

### 4. Advanced Compose-Spec Translation Matrix

CUE doesn't just support basic services; it handles complex dependency trees and environment logic that standard K3s `kompose` tools often fail on:

| Compose Feature | CUE Implementation Strategy | Benefit |
| :--- | :--- | :--- |
| `depends_on: condition: service_healthy` | **Cluster-Aware Init Containers.** CUE injects a "wait-for" init container that queries the cluster metadata for the healthy status of the dependency before starting the main process. | Zero race conditions during multi-node startup. |
| `extends: / include:` | **Pre-processor Merge.** CUE resolves all YAML imports and inheritance locally before submitting to the Kine API. | Maintainable, modular configuration across large projects. |
| `networks: aliases:` | **Internal DNS Records.** Peer names are registered in the Hairpin-DNS layer, allowing `db` to resolve to the correct pod regardless of the real container ID. | Identical networking behavior to local `docker-compose`. |
| `env_file:` | **Secrets/ConfigMap Fusion.** CUE reads local `.env` files and injects them as transient environment variables or K8s Secrets depending on the presence of the `SECRETS` keyword. | Secure defaults without changing file structure. |

***

## 🛠️ The "Intuitive Operator" Experience

Infrastructure shouldn't just be powerful; it should be *intuitive*. CUE treats the developer's CLI as the primary interface, not a dense web portal or a mountain of YAML.

### 1. `cue` CLI: The Swiss Army Knife

The `cue` binary acts as both the server and the primary client. It mimics the syntax of common tools to reduce muscle-memory friction:

* `cue up -d`: Deploys the current project (maps to `kubectl apply`).
* `cue ps`: Shows all services across the **entire cluster**, showing which node they are running on.
* `cue logs -f`: Aggregates logs from all replicas of a service, even if they span 3 nodes.
* `cue exec -it`: Spawns a terminal into a container regardless of its physical location in the mesh.

### 2. Auto-Discovery & "Magic" Ingress

In standard K8s, setting up an Ingress requires a `Service`, an `Ingress` object, and a `Cert-Manager` Issuer.
**The CUE approach**:
Simply add the Traefik labels you already use in Docker Compose:

```yaml
labels:
  - "traefik.http.routers.myapp.rule=Host(`myapp.bolabaden.org`)"
```

CUE's controller detects these labels and **atomically generates** the K8s Service, Ingress, and ACME Challenge records. It removes 30-40 lines of boilerplate YAML per service.

***

## ⚡ Zero-ENV Single-Command Boostrapper

To eliminate configuration drift, human error, and manual steps (detailed in [Docker Secrets Setup](DOCKER_SECRETS_README.md)), CUE introduces a fully integrated, zero-configuration bootstrap command.

```bash
# To bootstrap a brand-new multi-node cluster, run a single script:
curl -fsSL https://get.bolabaden.org | sh -s bootstrap --role master --domain bolabaden.org --cloudflare-api-key $CF_KEY
```

Under the hood, the bootstrap daemon performs the following automated steps sequentially:

```text
        ┌─────────────────────────────────────────────────────────┐
        │  1. Check Host OS & Install pre-compiled Go CUE Binary  │
        └────────────────────────────┬────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  2. Automatically generate Cryptographic Secrets & Keys │
        │     • WireGuard private/public keys                     │
        │     • Cluster Node Join Token                           │
        │     • Master Database Signing Secrets & Certificates   │
        └────────────────────────────┬────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  3. Spin up Tailscale/Headscale Private VPN Mesh       │
        │     • Generate mesh controller container                │
        │     • Automatically route 100.64.0.0/10 nodes           │
        └────────────────────────────┬────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  4. Mount local tmpfs credentials & verify permissions  │
        └────────────────────────────┬────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  5. Launch Core System Plane Stack                      │
        │     • Traefik v3 HTTP Ingress                           │
        │     • Watchtower Registry Updater                       │
        │     • Dozzle Cross-Node Log Aggregator                  │
        │     • Deunhealth Host Watchdog                          │
        └─────────────────────────────────────────────────────────┘
```

When adding a secondary node to the cluster, the operator simply executes:

```bash
# On Server B, simply run:
curl -fsSL https://get.bolabaden.org | sh -s join --token <TOKEN_FROM_MASTER> --master-ip <MASTER_TAILSCALE_IP>
```

Server B automatically installs CUE, connects to the existing private VPN mesh over Tailscale, downloads system configuration secrets securely, and joins the cluster database. Within seconds, it begins running applications scheduled across the cluster, completely eliminating the manual VPS setups highlighted in `cloud-init-bootstrap.sh`.

***

## ⚓ The default "System Plane" Stack

Every nodes running CUE automatically launches our core "system-plane" services, packaged natively within the CUE single-binary as embedded Docker Compose resources. They require zero manual configuration, zero environment variables from the user, and are instantly fully operational.

### 1. Traefik v3 (Edge Ingress Engine)

* **Role**: Standard border router, L7 load balancer, and TLS termination manager.
* **Embedded Config**: Configured out-of-the-box with a dynamic Let's Encrypt Acme client integrated with the cluster's Cloudflare verification layer.
* **Automatic Wildcards**: Routes external queries for `*.bolabaden.org` to local container endpoints, querying the cluster's internal state directory dynamically (replaces static files via Traefik.go's implementation in [Constellation Agent Configuration](infra/docs/CONFIGURATION.md)).
* **L4 Routing**: Exposes dynamic HAProxy tunnels (modeled on `compose/docker-compose.l4-ingress.yml`) using Traefik's native TCP routers for database services.

### 2. Watchtower (Zero-Downtime Updater)

* **Role**: Tracks Docker repository changes for user containers.
* **Embedded Config**: Runs container state monitoring sweeps on a randomized schedule to reduce OOM crashes.
* **Graceful Termination**: Captures the Linux SIGTERM signal inside applications. Initiates connection-draining of web requests at Traefik before executing updates, avoiding brutal teardowns highlighted in [plan-infrastructure-unification.md](plan-infrastructure-unification.md).

### 3. Dozzle (Real-time Cluster Logs)

* **Role**: Secure, lightweight log aggregator.
* **Embedded Config**: Binds virtual socket `/var/run/docker.sock` to collect container streams, projecting live multi-node logs into a single authenticated cluster page (`dozzle.bolabaden.org`).

### 4. Deunhealth (Healer)

* **Role**: Background container health monitor.
* **Embedded Config**: Monitors container runtimes for unhealthy states, executing automated container recreation triggers while preserving localized volumes.

***

## 🔒 Security Architecture

CUE implements a strict, enterprise-ready zero-trust security paradigm:

1. **Tmpfs Secrets Isolation**: All secrets specified in Compose files are mounted strictly to in-memory, secure `tmpfs` directories (`/run/secrets/`). They are never compiled into Docker image layers, written to the local disk, or outputted as transparent environmental text.
2. **Read-Only System Volumes**: Core configuration structures, cert volumes, and binary assemblies are mounted as read-only systems to prevent injection of malicious runtime scripts.
3. **Implicit VPN Isolation**: All inter-node data transmission traverses the dynamically configured Tailscale Core Mesh network, encrypted end-to-end via WireGuard. No internal services or backend registries (e.g. MongoDB, Redis, or Prometheus) are exposed to the public internet.

***

## 🗺️ Implementation Roadmap & Milestones

Bringing CUE to fruition is structured into four distinct development phases, prioritizing core CLI and translation stability first before moving to distributed consensus layers:

### Phase 1: Local Single-Binary Core & Translator (Month 1 - Month 3)

* Compile standalone CUE binary wrapping `containerd` and Kine database engines.
* Build the Compose-Specification to Kubernetes schema translator.
* Implement the local Virtual Docker Socket emulation layer so Dozzle/Watchtower run successfully on container instances.

### Phase 2: Mesh and Automated Boostrapper (Month 3 - Month 6)

* Implement `cue bootstrap` CLI scripts for single-command machine provisioning.
* Native integration of Headscale/Tailscale mesh VPN modules inside CUE Go codebase.
* Implement automatic cryptographic password/secret key directories generation.

### Phase 3: Distributed State & Failover Controllers (Month 6 - Month 9)

* Integrate HashiCorp Memberlist (Gossip) for unified service detection across nodes.
* Implement Raft-based distributed consensus for load balancer leadership and dynamic Cloudflare DNS updates.
* Synchronize dynamic Traefik v3 router files across nodes.

### Phase 4: Production Verification & Scaling (Month 9+)

* Move all 57+ docker-compose stacks (`docker-compose.yml`) to run natively on CUE.
* Test geographical node outages, connection packet drops, and automatic failover times.
* Release stable 1.0.0 distribution templates for the community.

***

## 🔄 Migration Path: From Legacy to CUE

Transitioning from the current manual "no-orchestrator" setup to CUE is designed to be a "Zero-Rename" process:

1. **Phase 1 (Sidecar)**: Install CUE on an existing node. It will detect currently running Docker containers and "Claim" them in its read-only dashboard without stopping them.
2. **Phase 2 (Shadow Mode)**: Apply your `docker-compose.yml` via `cue up -d`. CUE will verify it can reconcile the requirements (networks, volumes) before proceeding.
3. **Phase 3 (Takeover)**: On confirmation, CUE stops the standalone Docker container and immediately reinstantiates it as a managed CUE Pod, mounting the existing local volumes.
4. **Phase 4 (Expansion)**: Run `cue join` on other nodes. CUE detects the service mesh and automatically converts local network aliases into cluster-wide Anycast addresses.
