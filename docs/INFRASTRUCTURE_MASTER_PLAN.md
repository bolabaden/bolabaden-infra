# Bolabaden Infrastructure Master Plan

> **Version**: 1.0.0  
> **Date**: 2026-03-03  
> **Status**: Design & Planning  
> **Goal**: Turn a multi-VPS Docker Compose stack into a fully automated, self-healing, horizontally-scalable personal cloud that anyone can template for their own domain.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Architecture Overview](#3-architecture-overview)
4. [Module 1: Secret & Env Sync Across VPS Nodes](#4-module-1-secret--env-sync-across-vps-nodes)
5. [Module 2: Docker Compose File Sync](#5-module-2-docker-compose-file-sync)
6. [Module 3: Headscale HA (Leader Election)](#6-module-3-headscale-ha-leader-election)
7. [Module 4: Service Failover & Auto-Redeploy](#7-module-4-service-failover--auto-redeploy)
8. [Module 5: Cloudflare DDNS Multi-Record Load Balancing](#8-module-5-cloudflare-ddns-multi-record-load-balancing)
9. [Module 6: DNS Routing Pattern & ACL](#9-module-6-dns-routing-pattern--acl)
10. [Module 7: Traefik Catchall Router Fix](#10-module-7-traefik-catchall-router-fix)
11. [Module 8: Internal Tailscale DNS](#11-module-8-internal-tailscale-dns)
12. [Module 9: Watchtower Fix](#12-module-9-watchtower-fix)
13. [Module 10: Rate Limiting, Auth & Paid Tiers](#13-module-10-rate-limiting-auth--paid-tiers)
14. [Module 11: Meditation Wizard Lobby](#14-module-11-meditation-wizard-lobby)
15. [Unified Bootstrap Flow](#15-unified-bootstrap-flow)
16. [Templating for Others](#16-templating-for-others)
17. [Roadmap & Milestones](#17-roadmap--milestones)
18. [Appendices](#18-appendices)

---

## 1. Executive Summary

Bolabaden is a multi-node Docker infrastructure that runs the same `docker-compose.yml` and `cloud-init-bootstrap.sh` across multiple VPSes. Each node can independently serve requests or proxy to peers via Traefik. Cloudflare DNS with multiple A records provides node-level failover.

**This plan addresses 11 capability gaps** to transform the stack from a manually-synchronized multi-VPS setup into a fully automated, self-healing, horizontally-scalable platform.

### Core Principles

| Principle | Description |
|-----------|-------------|
| **No Orchestrator** | No Kubernetes, no Docker Swarm. Automation via lightweight agents. |
| **Git as Source of Truth** | All config lives in the bolabaden-infra repo. Changes flow through git. |
| **Idempotent Everything** | Every script, every sync, every deploy can run N times safely. |
| **Headscale Mesh** | All nodes communicate via Tailscale/Headscale private network. |
| **Inline Configs** | Docker Compose configs are inline YAML, not external files. |
| **Template-Ready** | Anyone can fork, set their domain/secrets, and deploy their own cloud. |

---

## 2. Current State Analysis

### What Exists Today

| Component | Status | Location |
|-----------|--------|----------|
| Bootstrap script | ✅ Fully idempotent | `cloud-init-bootstrap.sh` |
| Docker Compose (main) | ✅ Working | `docker-compose.yml` |
| Modular compose includes | ✅ 7 includes | `compose/docker-compose.*.yml` |
| Traefik v3 reverse proxy | ✅ With CrowdSec, ACME | `compose/docker-compose.coolify-proxy.yml` |
| Headscale | ✅ Single-node | `compose/docker-compose.headscale.yml` |
| Cloudflare DDNS | ✅ Single-record | `compose/docker-compose.coolify-proxy.yml` (favonia/cloudflare-ddns) |
| CrowdSec WAF | ✅ Working | Bouncer plugin + LAPI |
| TinyAuth | ✅ OAuth (Google/GitHub) | Forward auth middleware |
| nginx-traefik-extensions | ✅ API key + IP whitelist + TinyAuth fallback | Nginx forward auth |
| Watchtower | ⚠️ Configured but non-functional | `docker-compose.yml` service |
| Authentik | ⚠️ Defined but not in main include | `compose/docker-compose.authentik.yml` |
| docker-gen-failover | ❌ Bug: deletes routes on container stop | Template-based Traefik config |
| Nomad/Consul | ⚠️ Installed by bootstrap, not integrated | Bootstrap installs binaries |
| Secret sync | ❌ Manual | `.secrets` file, `generate-secrets.sh` |
| Compose sync | ❌ Manual git pull | Bootstrap does `git pull --ff-only` |
| Service failover | ❌ Not automated | Only Cloudflare DNS failover |

### Identified Bugs

1. **docker-gen-failover** removes Traefik routes when a container stops (defeats failover purpose)
2. **Watchtower** never successfully updates containers (auth/config issues)
3. **Traefik catchall router** intercepts frontend POST requests that should stay client-side (affects ai-researchwizard static frontend)
4. **Cloudflare DDNS** overwrites existing A/AAAA records instead of appending (breaks multi-VPS DNS)

---

## 3. Architecture Overview

### Target Architecture

```
                    ┌─────────────────────────────────────┐
                    │          Cloudflare DNS               │
                    │  *.bolabaden.org → [VPS1, VPS2, VPS3] │
                    │  (Multiple A/AAAA records per host)   │
                    └─────────┬───────────┬─────────────────┘
                              │           │
                    ┌─────────▼───┐ ┌─────▼──────────┐
                    │   VPS 1     │ │   VPS 2        │ ...
                    │ (athena)    │ │ (zeus)         │
                    ├─────────────┤ ├────────────────┤
                    │ Traefik     │ │ Traefik        │
                    │ CrowdSec    │ │ CrowdSec       │
                    │ Headscale●  │ │ Headscale(stby)│
                    │ Services... │ │ Services...    │
                    └──────┬──────┘ └───────┬────────┘
                           │ Tailscale Mesh │
                           └────────────────┘
                                  │
                    ┌─────────────▼──────────────────┐
                    │       Sync Agent (per node)     │
                    │  • Watches git for changes      │
                    │  • Syncs secrets via Headscale   │
                    │  • Redeploys affected containers │
                    │  • Reports health to peers       │
                    └─────────────────────────────────┘
```

### DNS Routing Pattern

```
bolabaden.org                  → All VPS IPs (round-robin)
*.bolabaden.org                → All VPS IPs (round-robin)
athena.bolabaden.org           → VPS1 only (specific node)
*.athena.bolabaden.org         → VPS1 only (services on specific node)
grafana.bolabaden.org          → All VPS IPs (any node with grafana)
grafana.athena.bolabaden.org   → VPS1 only (grafana on athena)
```

### Internal DNS (Tailscale/Headscale MagicDNS)

```
athena.myscale.bolabaden.org                → Tailscale IP of VPS1
grafana.athena.myscale.bolabaden.org        → Resolved by CoreDNS on each node
grafana.myscale.bolabaden.org               → Any node running grafana
```

---

## 4. Module 1: Secret & Env Sync Across VPS Nodes

### Problem

Changing `OPENAI_API_KEY` or any secret requires manually updating every VPS's `.env`/`.secrets` files and restarting affected containers.

### Current Implementation

- Secrets stored as individual files in `${SECRETS_PATH}/` (e.g., `secrets/cf-api-token.txt`)
- Environment variables in `.env` file at stack root
- Bootstrap merges `.secrets` into `.env` during deploy
- `generate-secrets.sh` creates placeholder secret files

### Design

#### Component: `bolabaden-sync-agent` (Docker container on every node)

```yaml
# New service added to docker-compose.yml
bolabaden-sync-agent:
  image: ghcr.io/bolabaden/sync-agent:latest
  container_name: sync-agent
  hostname: sync-agent
  volumes:
    - ${DOCKER_SOCKET:-/var/run/docker.sock}:/var/run/docker.sock:ro
    - ${ROOT_PATH:-.}:/workspace:rw
    - ${SECRETS_PATH:?}:/secrets:rw
  environment:
    SYNC_MODE: ${SYNC_MODE:-pull}           # pull | push | bidirectional
    SYNC_INTERVAL: ${SYNC_INTERVAL:-60}     # seconds
    SYNC_SOURCE: ${SYNC_SOURCE:-git}        # git | consul | redis
    RESTART_ON_SECRET_CHANGE: ${RESTART_ON_SECRET_CHANGE:-prompt}  # auto | prompt | never
    REBUILD_ON_SECRET_CHANGE: ${REBUILD_ON_SECRET_CHANGE:-never}   # auto | prompt | never
    GIT_REPO: ${GIT_REPO:-https://github.com/bolabaden/bolabaden-infra.git}
    GIT_BRANCH: ${GIT_BRANCH:-main}
    HEADSCALE_API_URL: http://headscale-server:8081
    NODE_ID: ${TS_HOSTNAME}
    DOMAIN: ${DOMAIN}
```

#### Secret Sync Flow

```
1. Secret changed on any node (or in git)
       │
2. sync-agent detects change (file watcher + git poll + Headscale peer broadcast)
       │
3. Determines which containers use the changed secret/env var
   └── Inspects docker compose config JSON for secret/env references
       │
4. Based on RESTART_ON_SECRET_CHANGE:
   ├── auto:   docker compose up -d --force-recreate <affected_services>
   ├── prompt: Sends notification (Slack/Discord/webhook), waits for approval
   └── never:  Logs change, does not restart (takes effect on next manual restart)
```

#### Secret Distribution Mechanism

**Option A: Git-based (recommended for simplicity)**

- Secrets are **encrypted** with `age`/`sops` and committed to a private branch or separate repo
- Each node's sync-agent decrypts using a node-specific key stored in Tailscale's secret store
- Changes detected via `git diff` on pull

**Option B: Headscale Peer Broadcast**

- Leader node pushes secrets over Tailscale WireGuard tunnel via simple HTTP API
- Each node runs a lightweight receiver that writes to `${SECRETS_PATH}/`
- Authenticated via Tailscale identity (no extra auth needed)

**Option C: Consul KV (if Consul is enabled)**

- Secrets stored in Consul KV with ACLs
- `consul-template` or sync-agent watches for changes
- Already partially supported since bootstrap installs Consul

#### Configuration Matrix

| Env Var | Default | Description |
|---------|---------|-------------|
| `SYNC_MODE` | `pull` | `pull` = only fetch, `push` = propagate local changes, `bidirectional` = both |
| `SYNC_INTERVAL` | `60` | Seconds between sync checks |
| `RESTART_ON_SECRET_CHANGE` | `prompt` | `auto` / `prompt` / `never` |
| `REBUILD_ON_SECRET_CHANGE` | `never` | `auto` / `prompt` / `never` (for services with `build:`) |
| `SECRET_ENCRYPTION_KEY` | (required) | `age` public key for decryption |
| `SYNC_NOTIFICATION_URL` | (empty) | Shoutrrr URL for notifications |

#### Implementation Steps

1. Create `scripts/sync-agent/` with Python or Go agent
2. Implement file watcher for `${SECRETS_PATH}/` and `.env`
3. Implement git pull + diff detection
4. Implement container dependency resolution (parse compose config JSON)
5. Implement restart/rebuild logic with configurable behavior
6. Add encrypted secrets workflow with `sops`/`age`
7. Add Headscale peer discovery for push mode
8. Package as Docker image `ghcr.io/bolabaden/sync-agent`

---

## 5. Module 2: Docker Compose File Sync

### Problem

Changing `docker-compose.yml` or any `compose/*.yml` file requires manually pulling on every VPS.

### Current Implementation

- Bootstrap does `git pull --ff-only` on the infra repo
- No automatic detection of compose file changes
- No automatic `docker compose up` after changes

### Design

The sync-agent from Module 1 handles this as well:

```
1. Git pull detects changed compose files
       │
2. Runs `docker compose config` to validate
       │
3. Diff analysis: which services changed?
   └── Compare previous vs new compose config JSON
       │
4. For changed services:
   ├── New service added:     docker compose up -d <new_service>
   ├── Service config changed: docker compose up -d --force-recreate <service>
   ├── Service removed:       docker compose rm -sf <service>
   └── Only labels changed:   docker compose up -d <service> (no restart needed)
       │
5. Rollback on failure:
   └── git stash pop / git checkout previous commit for that file
```

#### Compose Change Detection

```python
# Pseudocode for compose diff detection
def detect_compose_changes(old_config, new_config):
    changes = []
    for service_name in set(list(old_config['services'].keys()) + list(new_config['services'].keys())):
        old_svc = old_config['services'].get(service_name)
        new_svc = new_config['services'].get(service_name)
        
        if old_svc is None:
            changes.append(('added', service_name))
        elif new_svc is None:
            changes.append(('removed', service_name))
        elif old_svc != new_svc:
            # Determine what changed
            if old_svc.get('image') != new_svc.get('image'):
                changes.append(('image_changed', service_name))
            elif old_svc.get('environment') != new_svc.get('environment'):
                changes.append(('env_changed', service_name))
            elif old_svc.get('labels') != new_svc.get('labels'):
                changes.append(('labels_only', service_name))
            else:
                changes.append(('config_changed', service_name))
    return changes
```

#### Safety Mechanisms

- **Pre-validation**: Always run `docker compose config` before applying
- **Canary deploy**: On multi-node, update one node first, health-check, then propagate
- **Auto-rollback**: If service fails health check within 2 minutes of update, revert
- **Excluded services**: Honor `STACK_EXCLUDE_SERVICES` env var from bootstrap

---

## 6. Module 3: Headscale HA (Leader Election)

### Problem

Headscale is a singleton service — if the node running it goes down, the entire Tailscale mesh loses its control plane.

### Current Implementation

- Single `headscale-server` container defined in `compose/docker-compose.headscale.yml`
- SQLite database at `/var/lib/headscale/db.sqlite`
- No replication or failover

### Design: Leader Election via Lightweight Distributed Lock

#### Approach: Redis-based Leader Election

Since Redis is already in the stack, use it for distributed locking:

```yaml
# New service: headscale-sentinel
headscale-sentinel:
  image: ghcr.io/bolabaden/headscale-sentinel:latest
  container_name: headscale-sentinel
  environment:
    REDIS_URL: redis://redis:6379
    NODE_ID: ${TS_HOSTNAME}
    LOCK_KEY: headscale-leader
    LOCK_TTL: 30            # seconds
    CHECK_INTERVAL: 10      # seconds
    HEADSCALE_COMPOSE_FILE: compose/docker-compose.headscale.yml
    DOCKER_SOCKET: /var/run/docker.sock
  volumes:
    - ${DOCKER_SOCKET:-/var/run/docker.sock}:/var/run/docker.sock
```

#### Election Flow

```
Every CHECK_INTERVAL seconds on each node:
  │
  ├── Try to acquire Redis lock "headscale-leader" with TTL
  │   ├── SUCCESS: I am the leader
  │   │   ├── Is headscale-server running locally?
  │   │   │   ├── YES: Refresh lock, continue
  │   │   │   └── NO:  Start headscale-server, restore DB from latest backup
  │   │   └── Upload DB backup to shared storage every 5 minutes
  │   │
  │   └── FAILURE: Another node is leader
  │       ├── Is headscale-server running locally?
  │       │   ├── YES: Stop it (gracefully)
  │       │   └── NO:  Good, do nothing
  │       └── Verify leader is healthy (ping headscale API via Tailscale)
  │           └── If unhealthy for 3 consecutive checks: force-release lock
```

#### Database Replication

Since Headscale uses SQLite, use **Litestream** for real-time SQLite replication:

```yaml
headscale-server:
  # ... existing config ...
  # Add Litestream sidecar for SQLite replication
  volumes:
    - headscale-data:/var/lib/headscale
    
# Litestream sidecar replicates SQLite to S3/MinIO/NFS
headscale-litestream:
  image: litestream/litestream
  container_name: headscale-litestream
  volumes:
    - headscale-data:/var/lib/headscale
  environment:
    LITESTREAM_S3_ENDPOINT: ${LITESTREAM_S3_ENDPOINT:-}
    LITESTREAM_S3_BUCKET: ${LITESTREAM_S3_BUCKET:-headscale-backup}
  command: replicate /var/lib/headscale/db.sqlite s3://${LITESTREAM_S3_BUCKET}/db.sqlite
```

**Alternative (no S3)**: Sync SQLite via `rsync` over Tailscale to standby nodes every 5 minutes.

#### Failover Timeline

| Event | Time to Detect | Time to Recover | Total |
|-------|---------------|-----------------|-------|
| Leader node dies | 30s (lock TTL) | 10s (start container) + 5s (restore DB) | ~45s |
| Headscale container crashes | 10s (health check) | 5s (restart) | ~15s |
| DB corruption | Immediate (Litestream) | 30s (restore from replica) | ~30s |

---

## 7. Module 4: Service Failover & Auto-Redeploy

### Problem

When a service/container fails on one node, there's no automatic failover to another node. The `docker-gen-failover` approach has a critical bug: it deletes Traefik routes when containers stop.

### Current Implementation (Broken)

```yaml
# docker-gen-failover in docker-compose.coolify-proxy.yml
docker-gen-failover:
  image: docker.io/nginxproxy/docker-gen
  command: |
    -endpoint tcp://dockerproxy-rw:2375
    -only-exposed
    -include-stopped           # <-- This is set, but...
    -event-filter event=start  # <-- Only generates on START events
    -event-filter event=create
    # Missing: -event-filter event=die    <-- This causes route deletion on stop
    # Missing: -event-filter event=stop
    -watch /templates/traefik-failover-dynamic.conf.tmpl /traefik/dynamic/failover-fallbacks.yaml
```

**Root Cause of Bug**: docker-gen re-runs the template on events. When a container stops, docker-gen regenerates the template **without** the stopped container's data (even with `-include-stopped`), effectively deleting its Traefik route. This is because the template iterates over containers and only generates routes for those with `traefik.enable=true` — stopped containers lose their labels from the docker-gen context.

### Design: Replace docker-gen with `bolabaden-failover-agent`

#### Architecture

```
                 ┌──────────────────────────────┐
                 │   bolabaden-failover-agent    │
                 │   (runs on every node)        │
                 ├──────────────────────────────┤
                 │ 1. Maintains service registry │
                 │    (YAML file, never deletes  │
                 │     routes on container stop)  │
                 │                                │
                 │ 2. Health checks all services  │
                 │    via Traefik health endpoints │
                 │                                │
                 │ 3. On failure detection:        │
                 │    a. Try local restart (3x)    │
                 │    b. Notify peer nodes         │
                 │    c. Peer picks up service     │
                 │                                │
                 │ 4. Generates Traefik dynamic    │
                 │    config with ALL known routes │
                 │    (local + remote peers)       │
                 └──────────────────────────────┘
```

#### Service Registry (`services.yaml`)

```yaml
# Distributed to all nodes via sync-agent
# NEVER removes entries on container stop — only marks them as down
services:
  grafana:
    type: http
    port: 3000
    healthcheck_path: /api/health
    healthcheck_interval: 30s
    nodes:
      athena:
        status: healthy       # healthy | unhealthy | stopped | unknown
        last_seen: 2026-03-03T12:00:00Z
        priority: 1           # lower = preferred
      zeus:
        status: stopped
        last_seen: 2026-03-03T11:55:00Z
        priority: 2
    failover:
      enabled: true
      max_retries: 3
      redeploy_on_peer: true  # auto-start on another node if all local retries fail
      
  headscale-server:
    type: http
    port: 8081
    singleton: true            # only one instance across all nodes
    nodes:
      athena:
        status: healthy
        priority: 1
    failover:
      enabled: true
      singleton_election: redis  # Use Redis lock for singleton
```

#### Traefik Dynamic Config Generation (Fixed)

The key fix is to **always** include all known routes, using weighted load balancing with health checks:

```yaml
# Generated by failover-agent (NEVER deleted on container stop)
http:
  routers:
    grafana:
      rule: Host(`grafana.bolabaden.org`)
      service: grafana-failover@file
      
  services:
    grafana-failover:
      loadBalancer:
        healthCheck:
          path: /api/health
          interval: 15s
          timeout: 5s
        servers:
          - url: http://grafana:3000          # Local (fast path)
          - url: https://grafana.athena.bolabaden.org  # Peer via Traefik
          - url: https://grafana.zeus.bolabaden.org    # Another peer
```

Traefik's built-in health checking will automatically route around failed backends.

#### Failover Sequence

```
Container fails on Node A:
  │
  ├── 1. Traefik detects unhealthy (15s health check interval)
  │      └── Stops routing to local backend
  │      └── Routes to peer nodes automatically
  │
  ├── 2. Failover agent detects failure (Docker event + health check)
  │      └── Attempts local restart (up to 3 times, 10s apart)
  │      └── If restart succeeds: done
  │
  ├── 3. If local restart fails after 3 attempts:
  │      └── Marks service as "failed" in services.yaml
  │      └── Broadcasts to peer nodes via Headscale mesh
  │      └── Peer with lowest priority picks up service
  │           └── docker compose up -d <service>
  │
  └── 4. When Node A recovers:
         └── Service starts automatically (compose restart: always)
         └── Traefik health check detects healthy
         └── Traffic gradually returns to Node A
```

---

## 8. Module 5: Cloudflare DDNS Multi-Record Load Balancing

### Problem

The current `favonia/cloudflare-ddns` image **replaces** existing A/AAAA records with the current node's IP. When multiple VPSes run it, they overwrite each other.

### Current Implementation

```yaml
cloudflare-ddns:
  image: docker.io/favonia/cloudflare-ddns:1
  environment:
    DOMAINS: $TS_HOSTNAME.$DOMAIN,*.$TS_HOSTNAME.$DOMAIN
    PROXIED: is($DOMAIN)||is(*.$DOMAIN)
    RECORD_COMMENT: 'Updated by Cloudflare DDNS on server `$TS_HOSTNAME.$DOMAIN`'
```

### Design: Fork `cloudflare-ddns` → `bolabaden/cloudflare-ddns-multi`

#### New Behavior

| Mode | Env Var | Behavior |
|------|---------|----------|
| **Replace** (default) | `CF_DDNS_MODE=replace` | Current behavior — overwrites existing records |
| **Append** | `CF_DDNS_MODE=append` | Adds this node's IP alongside existing records |
| **Managed** | `CF_DDNS_MODE=managed` | Only manages records tagged with this node's comment; leaves others alone |

#### Implementation

```python
# Pseudocode for multi-record DDNS logic
def update_dns_record(zone_id, domain, current_ip, mode, node_comment):
    existing_records = cf_api.list_dns_records(zone_id, name=domain, type='A')
    
    if mode == 'replace':
        # Original behavior: delete all, create one
        for record in existing_records:
            cf_api.delete(record.id)
        cf_api.create(zone_id, type='A', name=domain, content=current_ip, comment=node_comment)
        
    elif mode == 'append':
        # Check if our IP is already in the record set
        our_record = next((r for r in existing_records if r.content == current_ip), None)
        if our_record:
            # Update comment/TTL if needed
            cf_api.update(our_record.id, content=current_ip, comment=node_comment)
        else:
            # Add new record alongside existing ones
            cf_api.create(zone_id, type='A', name=domain, content=current_ip, comment=node_comment)
        
        # Clean up stale records from dead nodes (no heartbeat for >1h)
        for record in existing_records:
            if is_our_managed_record(record) and record.content != current_ip:
                if not is_node_alive(record.comment):
                    cf_api.delete(record.id)
                    
    elif mode == 'managed':
        # Only touch records with our node's comment
        our_records = [r for r in existing_records if node_comment in (r.comment or '')]
        if our_records:
            for record in our_records:
                cf_api.update(record.id, content=current_ip, comment=node_comment)
        else:
            cf_api.create(zone_id, type='A', name=domain, content=current_ip, comment=node_comment)
```

#### Docker Compose Update

```yaml
cloudflare-ddns:
  image: ghcr.io/bolabaden/cloudflare-ddns-multi:1
  environment:
    CLOUDFLARE_API_TOKEN_FILE: /run/secrets/cloudflare-api-token
    
    # Multi-record mode (NEW)
    CF_DDNS_MODE: ${CF_DDNS_MODE:-replace}  # replace | append | managed
    
    # Shared domain records (all VPS IPs, round-robin load balancing)
    DOMAINS: >-
      $DOMAIN,
      *.$DOMAIN,
      $TS_HOSTNAME.$DOMAIN,
      *.$TS_HOSTNAME.$DOMAIN
    
    # Node-specific records always use replace mode regardless of CF_DDNS_MODE
    # These ensure $TS_HOSTNAME.$DOMAIN always points to THIS specific VPS
    NODE_SPECIFIC_DOMAINS: >-
      $TS_HOSTNAME.$DOMAIN,
      *.$TS_HOSTNAME.$DOMAIN
    
    PROXIED: is($DOMAIN)||is(*.$DOMAIN)
    RECORD_COMMENT: 'bolabaden-ddns:$TS_HOSTNAME'  # Structured comment for node identification
    
    # Stale record cleanup
    CF_DDNS_STALE_TIMEOUT: ${CF_DDNS_STALE_TIMEOUT:-3600}  # seconds before removing a dead node's records
    CF_DDNS_HEALTH_CHECK_URL: ${CF_DDNS_HEALTH_CHECK_URL:-}  # URL to check if peer nodes are alive
```

#### Record Layout After Deploy (3 nodes)

```
# bolabaden.org A records (Cloudflare load balances / failover)
bolabaden.org     A  203.0.113.1  (athena) proxied  comment: bolabaden-ddns:athena
bolabaden.org     A  198.51.100.2 (zeus)   proxied  comment: bolabaden-ddns:zeus
bolabaden.org     A  192.0.2.3    (hera)   proxied  comment: bolabaden-ddns:hera

# Node-specific records (always single, always replace mode)
athena.bolabaden.org  A  203.0.113.1   proxied  comment: bolabaden-ddns:athena
zeus.bolabaden.org    A  198.51.100.2  proxied  comment: bolabaden-ddns:zeus
hera.bolabaden.org    A  192.0.2.3     proxied  comment: bolabaden-ddns:hera

# Wildcard records (all nodes)
*.bolabaden.org   A  203.0.113.1  proxied  comment: bolabaden-ddns:athena
*.bolabaden.org   A  198.51.100.2 proxied  comment: bolabaden-ddns:zeus
*.bolabaden.org   A  192.0.2.3    proxied  comment: bolabaden-ddns:hera
```

---

## 9. Module 6: DNS Routing Pattern & ACL

### Problem

Need a consistent, intuitive DNS routing pattern and API key-based ACL with auth fallbacks.

### Design

#### DNS Pattern

| Pattern | Resolves To | Example |
|---------|-------------|---------|
| `$DOMAIN` | All VPS IPs | `bolabaden.org` |
| `$TS_HOSTNAME.$DOMAIN` | Specific VPS | `athena.bolabaden.org` |
| `$SERVICE.$DOMAIN` | Any VPS running service | `grafana.bolabaden.org` |
| `$SERVICE.$TS_HOSTNAME.$DOMAIN` | Service on specific VPS | `grafana.athena.bolabaden.org` |

#### Traefik Default Rule (already exists, confirmed working)

```
--providers.docker.defaultRule=Host(`{{ normalize .ContainerName }}.$DOMAIN`) || Host(`{{ normalize .Name }}.$DOMAIN`) || Host(`{{ normalize .ContainerName }}.$TS_HOSTNAME.$DOMAIN`) || Host(`{{ normalize .Name }}.$TS_HOSTNAME.$DOMAIN`)
```

#### ACL Chain (Authentication Cascade)

```
Request arrives at Traefik
  │
  ├── 1. Check X-Api-Key header
  │   └── Valid API key? → ALLOW (auth_method: api_key)
  │
  ├── 2. Check source IP whitelist
  │   └── Internal/trusted IP? → ALLOW (auth_method: ip_whitelist)
  │
  ├── 3. Check TinyAuth session (OAuth)
  │   └── Valid session? → ALLOW (auth_method: tinyauth)
  │
  ├── 4. Check Authentik session (full IdP)
  │   └── Valid session? → ALLOW (auth_method: authentik)
  │
  └── 5. No auth? → Redirect to TinyAuth login page
```

#### Auto-Generated API Key on Bootstrap

```bash
# In cloud-init-bootstrap.sh, after deploy:
if [ ! -f "${SECRETS_PATH}/nginx-auth-api-key.txt" ]; then
  openssl rand -hex 32 > "${SECRETS_PATH}/nginx-auth-api-key.txt"
  log_success "Generated API key for nginx-traefik-extensions"
fi
```

#### nginx-traefik-extensions Enhancement

The current nginx config already implements the cascade correctly:

1. Check `X-Api-Key` header → if valid, return 200
2. Check IP whitelist → if whitelisted, return 200
3. Fall through to TinyAuth proxy

**New**: Add Authentik as an additional fallback between TinyAuth and denial:

```nginx
location /auth {
    # ... existing api_key and ip_whitelist checks ...
    
    # Try TinyAuth first
    proxy_pass http://tinyauth/api/auth/traefik;
    # If TinyAuth returns 401, try Authentik
    error_page 401 = @authentik_fallback;
}

location @authentik_fallback {
    proxy_pass http://authentik:9000/outpost.goauthentik.io/auth/traefik;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    # ... forward headers ...
}
```

---

## 10. Module 7: Traefik Catchall Router Fix

### Problem

The Traefik catchall router (priority 1) intercepts frontend POST requests in SPAs like ai-researchwizard's static frontend. The static frontend makes `fetch()` POST requests that should be handled by the same origin's backend (FastAPI on :8000), but the catchall router catches them.

### Root Cause Analysis

The current catchall:

```yaml
catchall:
  entryPoints:
    - web
    - websecure
  service: noop@internal
  rule: Host(`$DOMAIN`) || Host(`$TS_HOSTNAME.$DOMAIN`) || HostRegexp(`^(.+)$`)
  priority: 1
  middlewares:
    - traefikerrorreplace@file
```

**The issue**: When ai-researchwizard's static frontend (`index.html` served by FastAPI at `gptr.bolabaden.org`) makes a `fetch('/api/research', {method: 'POST'})`, this POST goes to the **same origin** (the FastAPI backend). However, if the FastAPI backend returns a non-2xx status or the route doesn't match FastAPI's routing, Traefik's error page middleware on the **catchall** kicks in.

The real problem is the `traefikerrorreplace` middleware on the catchall combined with the `bolabaden-error-pages` middleware on the websecure entrypoint:

```yaml
'--entryPoints.websecure.http.middlewares=bolabaden-error-pages@file,crowdsec@file,strip-www@file'
```

The `bolabaden-error-pages` middleware catches **all** 400-599 status codes and redirects to `bolabaden-nextjs@file /api/error/{status}`. This means:

1. Frontend does `POST /api/research` → FastAPI backend
2. If FastAPI responds with any 4xx/5xx (intentional or not), the error pages middleware **replaces the response** with its own error page
3. The frontend JavaScript never receives the expected response format

### Fix: Make Error Pages Middleware Respect `Accept` Headers

The solution is to **not** apply error pages to API requests. API clients send `Accept: application/json`, while browsers send `Accept: text/html`.

#### Option A: Conditional Error Pages via Header Check (Recommended)

Create a chain middleware that only applies error pages to HTML requests:

```yaml
traefik-dynamic.yaml:
  content: |
    http:
      routers:
        catchall:
          entryPoints:
            - web
            - websecure
          service: noop@internal
          rule: Host(`$DOMAIN`) || Host(`$TS_HOSTNAME.$DOMAIN`) || HostRegexp(`^(.+)$$`)
          priority: 1
          middlewares:
            - traefikerrorreplace@file
            
      middlewares:
        # Only apply error pages to browser requests (Accept: text/html)
        # API requests (Accept: application/json) pass through unchanged
        bolabaden-error-pages:
          errors:
            status:
              - 400-599
            service: bolabaden-nextjs@file
            query: /api/error/{status}
```

**And update the entrypoint to NOT apply error pages globally:**

```yaml
# BEFORE:
'--entryPoints.websecure.http.middlewares=bolabaden-error-pages@file,crowdsec@file,strip-www@file'

# AFTER: Remove bolabaden-error-pages from entrypoint, apply it per-router instead
'--entryPoints.websecure.http.middlewares=crowdsec@file,strip-www@file'
```

Then for services that WANT error pages (browser-facing), add it to their router:

```yaml
labels:
  traefik.http.routers.myservice.middlewares: bolabaden-error-pages@file
```

#### Option B: Regex-Based Route Exclusion

Add a higher-priority router for API paths that skips error pages:

```yaml
api-passthrough:
  entryPoints:
    - websecure
  service: noop@internal  # Will never match due to priority, but needed for router
  rule: HeadersRegexp(`Accept`, `application/json`) && HostRegexp(`^(.+)$$`)
  priority: 2  # Higher than catchall (1)
  # NO error page middleware here
```

#### Recommended Approach

**Option A** is the correct fix because:

1. It's future-proof — any new service automatically gets correct behavior
2. API requests (SPAs, `fetch()`, `XMLHttpRequest`) never get HTML error pages
3. Browser navigation still gets styled error pages
4. No per-service configuration needed

---

## 11. Module 8: Internal Tailscale DNS

### Problem

Need internal DNS within the Tailscale mesh so nodes and services can be addressed by hostname.

### Current Implementation

Headscale already has MagicDNS enabled:

```yaml
dns:
  magic_dns: true
  base_domain: myscale.$DOMAIN
```

This gives each node a hostname like `athena.myscale.bolabaden.org` on the Tailscale network.

### Design: Add Service-Level DNS with CoreDNS

#### CoreDNS Sidecar (per node)

```yaml
coredns-internal:
  image: docker.io/coredns/coredns
  container_name: coredns-internal
  hostname: coredns-internal
  networks:
    - backend
  configs:
    - source: coredns-corefile
      target: /etc/coredns/Corefile
    - source: coredns-zones
      target: /etc/coredns/zones/services.db
  expose:
    - 53
    - 53/udp
  restart: always
```

#### Corefile

```
configs:
  coredns-corefile:
    content: |
      myscale.$DOMAIN {
          # Service discovery: resolves $SERVICE.$TS_HOSTNAME.myscale.$DOMAIN
          # to the Docker container IP on that node
          file /etc/coredns/zones/services.db
          
          # Forward to Headscale for node-level resolution
          forward . 100.64.0.1
          
          log
          errors
      }
      
      # Fallback for everything else
      . {
          forward . 1.1.1.1 1.0.0.1
          cache 30
          log
          errors
      }
```

#### Zone File Generation (by sync-agent)

The sync-agent generates a zone file from running Docker containers:

```
; Auto-generated by bolabaden-sync-agent
; Service DNS records for $TS_HOSTNAME.myscale.$DOMAIN
$ORIGIN myscale.bolabaden.org.

; Node records (resolved by Headscale MagicDNS)
; athena.myscale.bolabaden.org → Tailscale IP

; Service records on this node
grafana.athena    IN  A  172.18.0.5    ; Docker container IP
redis.athena      IN  A  172.18.0.10
traefik.athena    IN  A  172.18.0.2

; Service records (any node) — points to local Traefik which proxies
grafana           IN  CNAME  athena.myscale.bolabaden.org.
redis             IN  CNAME  athena.myscale.bolabaden.org.
```

#### DNS Pattern Summary

| Query | Resolution |
|-------|-----------|
| `athena.myscale.bolabaden.org` | Headscale MagicDNS → Tailscale IP |
| `grafana.athena.myscale.bolabaden.org` | CoreDNS → Docker container IP |
| `grafana.myscale.bolabaden.org` | CoreDNS → CNAME to nearest available node |

---

## 12. Module 9: Watchtower Fix

### Problem

Watchtower has never successfully updated containers. Configured for daily 6am runs but doesn't actually pull or deploy.

### Current Configuration Analysis

```yaml
watchtower:
  environment:
    WATCHTOWER_SCHEDULE: 0 0 6 * * *      # 6am daily
    WATCHTOWER_POLL_INTERVAL: 86400        # Also 24h (conflicts with SCHEDULE)
    WATCHTOWER_MONITOR_ONLY: false
    WATCHTOWER_NO_PULL: false
    WATCHTOWER_NO_RESTART: false
    WATCHTOWER_CLEANUP: true
    WATCHTOWER_DEBUG: true                 # Good for diagnosing
    WATCHTOWER_LOG_LEVEL: debug
    REPO_USER: bolabaden
    REPO_PASS: ${SUDO_PASSWORD:?}          # ⚠️ Is this the correct registry password?
    WATCHTOWER_HTTP_API_UPDATE: false       # ⚠️ HTTP API disabled
    WATCHTOWER_HTTP_API_TOKEN: (empty)      # ⚠️ No API token set
```

### Root Cause Diagnosis

**Issue 1: `REPO_PASS` is set to `SUDO_PASSWORD`**  
This is likely the system password, not the Docker Hub/GHCR password. Watchtower auth fails silently.

**Issue 2: `WATCHTOWER_POLL_INTERVAL` conflicts with `WATCHTOWER_SCHEDULE`**  
When both are set, behavior is undefined. Watchtower docs say SCHEDULE takes precedence, but the poll interval still runs.

**Issue 3: No HTTP API for triggering updates**  
`WATCHTOWER_HTTP_API_UPDATE` is false and no token is set.

**Issue 4: `watchtower-config.json` mapped from `~/.docker/config.json`**  
This may not contain the correct auth for private registries.

### Fix

```yaml
watchtower:
  image: docker.io/containrrr/watchtower
  container_name: watchtower
  hostname: watchtower
  networks:
    - backend
  configs:
    - source: watchtower-config.json
      target: /config.json
      mode: 0444
  volumes:
    - ${DOCKER_SOCKET:-/var/run/docker.sock}:/var/run/docker.sock:rw
  environment:
    DOCKER_HOST: ${DOCKER_HOST:-unix:///var/run/docker.sock}
    DOCKER_API_VERSION: ${DOCKER_API_VERSION:-1.44}
    TZ: ${TZ:-America/Chicago}
    
    # Authentication: Use Docker config.json (already mounted)
    # Remove REPO_USER/REPO_PASS — they override config.json and are wrong
    # REPO_USER: REMOVED
    # REPO_PASS: REMOVED
    
    # Scheduling: Use ONLY schedule, remove poll interval
    WATCHTOWER_SCHEDULE: ${WATCHTOWER_SCHEDULE:-0 0 4 * * *}  # 4am daily (off-hours)
    # WATCHTOWER_POLL_INTERVAL: REMOVED (conflicts with SCHEDULE)
    
    # Update behavior
    WATCHTOWER_MONITOR_ONLY: ${WATCHTOWER_MONITOR_ONLY:-false}
    WATCHTOWER_NO_PULL: false
    WATCHTOWER_NO_RESTART: false
    WATCHTOWER_CLEANUP: true
    WATCHTOWER_ROLLING_RESTART: true        # Rolling restart for zero-downtime
    WATCHTOWER_TIMEOUT: ${WATCHTOWER_TIMEOUT:-60s}  # Increased from 10s
    
    # Labels: let containers opt-out via labels
    WATCHTOWER_LABEL_ENABLE: false          # Don't require opt-in label
    WATCHTOWER_LABEL_TAKE_PRECEDENCE: true  # But respect opt-out labels
    
    # HTTP API: Enable for manual triggers
    WATCHTOWER_HTTP_API_UPDATE: true
    WATCHTOWER_HTTP_API_TOKEN: ${WATCHTOWER_HTTP_API_TOKEN:-${NGINX_AUTH_API_KEY}}
    WATCHTOWER_HTTP_API_PERIODIC_POLLS: true
    WATCHTOWER_HTTP_API_METRICS: true
    
    # Logging
    WATCHTOWER_DEBUG: ${WATCHTOWER_DEBUG:-false}
    WATCHTOWER_LOG_LEVEL: ${WATCHTOWER_LOG_LEVEL:-info}
    
    # Notifications
    WATCHTOWER_NOTIFICATION_URL: ${WATCHTOWER_NOTIFICATION_URL:-}
    WATCHTOWER_NOTIFICATION_REPORT: true
  expose:
    - 8080
  labels:
    traefik.enable: false  # Internal only
    homepage.group: Infrastructure
    homepage.name: Watchtower
    homepage.icon: watchtower.png
    homepage.description: Automatic container image updates
  healthcheck:
    test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/v1/metrics || exit 1"]
    interval: 60s
    timeout: 10s
    retries: 3
    start_period: 30s
  restart: always
```

### Smart Redeployment (Phase 2)

For the "check if anyone is connected" feature, create a wrapper:

```bash
# scripts/watchtower-smart-update.sh
# Called by sync-agent when updates are available

for container in $(docker ps --format '{{.Names}}'); do
    # Check active connections via docker stats / ss
    CONNECTIONS=$(docker exec "$container" ss -tn 2>/dev/null | grep -c ESTAB || echo 0)
    
    if [ "$CONNECTIONS" -gt 0 ]; then
        echo "[$container] $CONNECTIONS active connections — deferring update"
        # Schedule for next maintenance window
    else
        echo "[$container] No active connections — safe to update"
        curl -H "Authorization: Bearer $WATCHTOWER_HTTP_API_TOKEN" \
             http://watchtower:8080/v1/update
    fi
done
```

---

## 13. Module 10: Rate Limiting, Auth & Paid Tiers

### Problem

Need tiered rate limiting: highest for anonymous, lower for registered, lowest for paid users.

### Design

#### Rate Limit Tiers

| Tier | Requests/min | Burst | Concurrent |
|------|-------------|-------|------------|
| Anonymous | 30 | 50 | 5 |
| Registered (free) | 100 | 200 | 20 |
| Paid | 1000 | 2000 | 200 |

#### Implementation: CrowdSec + Traefik Rate Limiting + Auth Headers

```yaml
# Traefik middleware chain per tier
middlewares:
  rate-limit-anonymous:
    rateLimit:
      average: 30
      burst: 50
      period: 1m
      sourceCriterion:
        ipStrategy:
          depth: 1
          
  rate-limit-registered:
    rateLimit:
      average: 100
      burst: 200
      period: 1m
      sourceCriterion:
        requestHeaderName: X-Auth-User
        
  rate-limit-paid:
    rateLimit:
      average: 1000
      burst: 2000
      period: 1m
      sourceCriterion:
        requestHeaderName: X-Auth-User
```

#### Auth Provider: Authentik (White-Labeled)

Use Authentik with custom branding:

```yaml
authentik:
  environment:
    # Custom branding
    AUTHENTIK_DEFAULT_TOKEN_LENGTH: 128
    AUTHENTIK_BRANDING__TITLE: "Bolabaden"
    AUTHENTIK_BRANDING__LOGO: "/static/dist/assets/icons/icon.svg"
    AUTHENTIK_BRANDING__FAVICON: "/static/dist/assets/icons/icon.svg"
  volumes:
    - ./static/authentik-custom:/web/dist/custom  # Custom CSS/JS/logos
```

Custom CSS to rebrand:

```css
/* Hide Authentik branding */
.pf-c-login__footer, .pf-c-page__footer { display: none !important; }
.ak-brand { content: url('/static/custom/logo.svg') !important; }
```

#### Nginx Rate Limit Integration (Enhanced)

Update `nginx-traefik-extensions.conf` to set rate limit tier headers:

```nginx
# After auth resolution, set tier header
map $auth_method $rate_tier {
    "api_key"      "paid";
    "ip_whitelist" "paid";
    "tinyauth"     "registered";
    "authentik"    "registered";
    default        "anonymous";
}

# Set header for Traefik rate limiting
add_header X-Rate-Tier $rate_tier always;
```

#### Rate Limit Exceeded → Meditation Lobby

When rate limit returns 429, redirect to the meditation lobby:

```yaml
middlewares:
  rate-limit-redirect:
    errors:
      status:
        - 429
      service: meditation-lobby@file
      query: /wait?reason=rate_limit&tier={tier}
```

---

## 14. Module 11: Meditation Wizard Lobby

### Problem

When users hit rate limits, show them an animated meditation wizard instead of a boring error page.

### Design

#### Service: `meditation-lobby`

A lightweight static web app with WebSocket connection for real-time packet visualization.

```yaml
meditation-lobby:
  image: ghcr.io/bolabaden/meditation-lobby:latest
  container_name: meditation-lobby
  hostname: meditation-lobby
  networks:
    - backend
    - publicnet
  expose:
    - 3000
  environment:
    IPTABLES_FEED_URL: ws://crowdsec:8080/v1/decisions/stream  # CrowdSec decision stream
    PACKET_FEED_ENABLED: ${MEDITATION_PACKET_FEED:-true}
  labels:
    traefik.enable: true
    traefik.http.routers.meditation-lobby.rule: Host(`wait.$DOMAIN`)
    traefik.http.services.meditation-lobby.loadbalancer.server.port: 3000
```

#### Visual Design Spec

```
┌──────────────────────────────────────────────────┐
│                 Rate Limit Reached                │
│          Please wait while we catch up...         │
│                                                   │
│              ┌─────────────────────┐              │
│              │                     │              │
│              │    🧙‍♂️ WIZARD        │              │
│              │  (cross-legged,     │              │
│              │   gandalf beard,    │              │
│              │   eyes closed,      │              │
│              │   meditating)       │              │
│              │                     │              │
│              │  ✨ Tinkerbell      │              │
│              │  fairies = allowed  │              │
│              │  packets fly in     │              │
│              │                     │              │
│              │  🔴 Red forcefield  │              │
│              │  = blocked packets  │              │
│              │  (translucent red   │              │
│              │   shield animation) │              │
│              │                     │              │
│              └─────────────────────┘              │
│                                                   │
│  Wizard smile level: ████████░░  80% (happy!)    │
│  Packets allowed: 1,234  |  Blocked: 56          │
│                                                   │
│  [Estimated wait: ~30 seconds]                    │
└──────────────────────────────────────────────────┘
```

#### Tech Stack

- **Frontend**: Vanilla HTML/CSS/JS + Canvas API or Three.js for 3D wizard
- **Animation**: CSS keyframes for meditation breathing + JS for particle system
- **Packet Feed**: WebSocket to backend that tails CrowdSec decision stream + iptables counters
- **Smile Mechanic**: More allowed packets → wider smile (CSS `transform: scaleX()` on mouth element)
- **Forcefield**: SVG circle with `opacity` animated by blocked packet rate

#### Packet Feed Backend

```python
# Lightweight WebSocket server
# Reads from: CrowdSec LAPI decisions stream + iptables counters

@websocket('/ws/packets')
async def packet_feed(websocket):
    while True:
        # Get CrowdSec decisions (blocked IPs)
        blocked = await crowdsec_client.get_new_decisions()
        
        # Get iptables counters (allowed packets)
        allowed = parse_iptables_counters()
        
        await websocket.send_json({
            'type': 'packet_update',
            'allowed': allowed,     # → tinkerbell fairy animation
            'blocked': len(blocked), # → red forcefield animation
            'smile_level': min(1.0, allowed / (allowed + len(blocked) + 1)),
            'timestamp': time.time()
        })
        
        await asyncio.sleep(0.5)  # 2 updates/sec
```

---

## 15. Unified Bootstrap Flow

### Updated `cloud-init-bootstrap.sh` Flow

```
1. System setup (hostname, packages, Docker, SSH, users)     ← EXISTS
2. Clone/update bolabaden-infra repo                         ← EXISTS
3. Create warp-nat-net Docker network                        ← EXISTS
4. Network optimization, DNS, Tailscale                      ← EXISTS
5. Generate .env and secrets                                 ← EXISTS
6. CrowdSec preflight                                        ← EXISTS

7. [NEW] Initialize SOPS/age encryption keys
   └── Generate node-specific age key
   └── Decrypt shared secrets from git

8. [NEW] Register node in services.yaml
   └── Add $TS_HOSTNAME to service registry
   └── Broadcast availability to peers via Headscale

9. [NEW] Leader election for singleton services
   └── Check Redis for headscale-leader lock
   └── Conditionally start Headscale

10. Docker Compose deploy                                    ← EXISTS (enhanced)
    └── [NEW] Start sync-agent first
    └── [NEW] Start failover-agent
    └── [NEW] Conditionally start singletons based on leader election
    └── Deploy all other services

11. [NEW] Post-deploy health verification
    └── Verify all services healthy
    └── Verify Traefik routes registered
    └── Verify Cloudflare DNS records updated
    └── Report node status to peers
```

---

## 16. Templating for Others

### Goal: Anyone Can Fork and Deploy

#### Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `$DOMAIN` | Primary domain | `bolabaden.org` |
| `$TS_HOSTNAME` | This node's hostname | `athena` |
| `$CLOUDFLARE_API_TOKEN` | Cloudflare API token | (secret) |
| `$ACME_RESOLVER_EMAIL` | Let's Encrypt email | `admin@bolabaden.org` |
| `$PRIMARY_USER` | Unix user | `ubuntu` |
| `$GITHUB_USERS` | SSH key import | `th3w1zard1` |

#### Quick Start for New Users

```bash
# 1. Fork bolabaden/bolabaden-infra
# 2. Clone to your VPS
git clone https://github.com/YOUR_USER/YOUR_FORK.git ~/my-stack
cd ~/my-stack

# 3. Copy and edit the template config
cp bootstrap-secrets.defaults.env my-config.env
# Edit: DOMAIN, CLOUDFLARE_API_TOKEN, etc.

# 4. Run bootstrap
sudo BOOTSTRAP_CONFIG_FILE=./my-config.env ./cloud-init-bootstrap.sh $(hostname -s)

# 5. Deploy additional VPS nodes
# Just run step 4 on each VPS — sync-agent handles the rest
```

#### What's Included Out of the Box

- Traefik reverse proxy with automatic TLS
- CrowdSec WAF + rate limiting
- Cloudflare DDNS (single or multi-record)
- Headscale/Tailscale mesh networking
- OAuth login (Google/GitHub via TinyAuth)
- Grafana + VictoriaMetrics monitoring
- Service health checking + auto-restart
- Watchtower auto-updates
- Automated storage maintenance
- Homepage dashboard

---

## 17. Roadmap & Milestones

### Phase 1: Foundation (Weeks 1-2)

| Task | Priority | Effort |
|------|----------|--------|
| Fix Watchtower (Module 9) | 🔴 Critical | 1 day |
| Fix Traefik catchall (Module 7) | 🔴 Critical | 1 day |
| Fix Cloudflare DDNS multi-record (Module 5) | 🔴 Critical | 3 days |
| Remove broken docker-gen-failover | 🟡 High | 30 min |

### Phase 2: Sync & Failover (Weeks 3-4)

| Task | Priority | Effort |
|------|----------|--------|
| Build sync-agent (Module 1 & 2) | 🔴 Critical | 5 days |
| Build failover-agent (Module 4) | 🔴 Critical | 5 days |
| Implement Headscale HA (Module 3) | 🟡 High | 3 days |

### Phase 3: DNS & Auth (Weeks 5-6)

| Task | Priority | Effort |
|------|----------|--------|
| Internal Tailscale DNS (Module 8) | 🟡 High | 2 days |
| DNS routing pattern finalization (Module 6) | 🟡 High | 2 days |
| Rate limiting + auth tiers (Module 10) | 🟡 High | 5 days |
| Authentik white-label integration | 🟢 Medium | 3 days |

### Phase 4: Polish & UX (Weeks 7-8)

| Task | Priority | Effort |
|------|----------|--------|
| Meditation wizard lobby (Module 11) | 🟢 Medium | 5 days |
| Template documentation | 🟢 Medium | 3 days |
| End-to-end testing across 3+ nodes | 🔴 Critical | 3 days |
| GitHub Actions CI/CD for image builds | 🟢 Medium | 2 days |

### Phase 5: Production Hardening (Ongoing)

| Task | Priority | Effort |
|------|----------|--------|
| Paid tier integration (Stripe) | 🟢 Medium | 5 days |
| Load testing (100+ concurrent users) | 🟡 High | 2 days |
| Disaster recovery runbook | 🟡 High | 2 days |
| Ansible playbooks for non-Docker tasks | 🟢 Medium | 3 days |

---

## 18. Appendices

### Appendix A: New Docker Images to Build

| Image | Source | Purpose |
|-------|--------|---------|
| `ghcr.io/bolabaden/sync-agent` | `scripts/sync-agent/` | Secret & compose sync |
| `ghcr.io/bolabaden/failover-agent` | `scripts/failover-agent/` | Service failover |
| `ghcr.io/bolabaden/headscale-sentinel` | `scripts/headscale-sentinel/` | Headscale HA |
| `ghcr.io/bolabaden/cloudflare-ddns-multi` | Fork of `favonia/cloudflare-ddns` | Multi-record DDNS |
| `ghcr.io/bolabaden/meditation-lobby` | `projects/meditation-lobby/` | Rate limit wait page |

### Appendix B: New Compose Services

```yaml
# To be added to docker-compose.yml includes:
include:
  - compose/docker-compose.coolify-proxy.yml
  - compose/docker-compose.firecrawl.yml
  - compose/docker-compose.headscale.yml
  - compose/docker-compose.llm.yml
  - compose/docker-compose.metrics.yml
  - compose/docker-compose.stremio-group.yml
  - compose/docker-compose.warp-nat-routing.yml
  - compose/docker-compose.sync.yml          # NEW: sync-agent + failover-agent
  - compose/docker-compose.internal-dns.yml  # NEW: CoreDNS for Tailscale DNS
  - compose/docker-compose.auth.yml          # NEW: Authentik + rate limiting
  - compose/docker-compose.lobby.yml         # NEW: Meditation lobby
```

### Appendix C: Environment Variables Reference (New)

| Variable | Default | Module | Description |
|----------|---------|--------|-------------|
| `SYNC_MODE` | `pull` | 1 | Secret sync mode |
| `SYNC_INTERVAL` | `60` | 1,2 | Sync check interval (seconds) |
| `RESTART_ON_SECRET_CHANGE` | `prompt` | 1 | Restart behavior on secret change |
| `REBUILD_ON_SECRET_CHANGE` | `never` | 1 | Rebuild behavior on secret change |
| `CF_DDNS_MODE` | `replace` | 5 | DDNS record mode |
| `CF_DDNS_STALE_TIMEOUT` | `3600` | 5 | Stale record cleanup timeout |
| `HEADSCALE_HA_ENABLED` | `false` | 3 | Enable Headscale leader election |
| `FAILOVER_ENABLED` | `true` | 4 | Enable service failover |
| `FAILOVER_MAX_RETRIES` | `3` | 4 | Local restart attempts before peer failover |
| `RATE_LIMIT_ANONYMOUS` | `30` | 10 | Requests/min for anonymous |
| `RATE_LIMIT_REGISTERED` | `100` | 10 | Requests/min for registered |
| `RATE_LIMIT_PAID` | `1000` | 10 | Requests/min for paid |
| `MEDITATION_PACKET_FEED` | `true` | 11 | Enable real-time packet visualization |

### Appendix D: File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `docker-compose.yml` | Modify | Add sync-agent service, fix watchtower |
| `compose/docker-compose.coolify-proxy.yml` | Modify | Fix catchall, update DDNS, remove docker-gen-failover |
| `compose/docker-compose.headscale.yml` | Modify | Add Litestream sidecar |
| `compose/docker-compose.sync.yml` | Create | Sync-agent + failover-agent |
| `compose/docker-compose.internal-dns.yml` | Create | CoreDNS for Tailscale |
| `compose/docker-compose.auth.yml` | Create | Authentik white-labeled |
| `compose/docker-compose.lobby.yml` | Create | Meditation lobby |
| `cloud-init-bootstrap.sh` | Modify | Add SOPS init, node registration, leader election |
| `scripts/sync-agent/` | Create | Sync agent source code |
| `scripts/failover-agent/` | Create | Failover agent source code |
| `scripts/headscale-sentinel/` | Create | Headscale HA sentinel |
| `projects/meditation-lobby/` | Create | Meditation lobby frontend |
| `services.yaml` | Create | Distributed service registry |

### Appendix E: Security Considerations

| Concern | Mitigation |
|---------|-----------|
| Secrets in git | Encrypted with `sops`/`age`, node-specific keys |
| Inter-node communication | All traffic over Tailscale/WireGuard tunnel |
| API key exposure | Keys stored in Docker secrets, never in env vars directly |
| Rate limit bypass | CrowdSec + Cloudflare WAF + Traefik rate limiting (defense in depth) |
| Auth session hijacking | Secure cookies, HTTPS only, short session TTL |
| DNS poisoning | DNSSEC enabled, Cloudflare proxy hides origin IPs |

---

*This document is the single source of truth for the Bolabaden infrastructure roadmap. All implementation PRs should reference the relevant module number.*
