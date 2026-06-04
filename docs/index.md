# bolabaden Infrastructure Knowledgebase

Welcome to the operational knowledgebase for **bolabaden.org** — a multi-node, Docker-based homelab infrastructure built for high availability **without** Kubernetes or Docker Swarm.

---

## Architecture at a Glance

```
User → Cloudflare DNS → Any Node
  ├─ Service exists locally? → Serve directly  (fast path)
  └─ Service on another node? → Traefik L7 proxy → Peer node
```

Key properties:

- **No central orchestrator** — services are manually assigned to nodes; the system reflects current state, not desired state
- **Distributed failover** — each node can independently serve requests or forward to peers
- **L7 reverse proxy** — Traefik v3 with file provider handles HTTPS routing, health checks, and primary + fallback configurations
- **DNS failover** — Cloudflare with multiple A records provides node-level failover
- **L4 proxy** — raw TCP services (Redis, MongoDB) handled separately

---

## Quick Navigation

| I want to… | Go to |
|---|---|
| Understand the overall roadmap | [Infrastructure Master Plan](INFRASTRUCTURE_MASTER_PLAN.md) |
| Understand the orchestration direction | [Orchestration Overview](../orchestration/README.md) |
| Deploy a new node or service | [Constellation Agent → Deployment Guide](../infra/docs/DEPLOYMENT_GUIDE.md) |
| Configure secrets | [Docker Secrets Setup](../DOCKER_SECRETS_README.md) |
| Troubleshoot a service | [Constellation Agent → Troubleshooting](../infra/docs/TROUBLESHOOTING.md) |
| Understand HA patterns | [Stateful HA Plan](stateful_ha_plan.md) |
| Run maintenance / clean up disk | [Maintenance Guide](MAINTENANCE.md) |
| Set up telemetry / metrics | [OTLP Quickstart](OTLP_QUICKSTART.md) |
| Contribute code or docs | [Contributing Guidelines](../CONTRIBUTING.md) |

---

## Infrastructure Components

### Core Services
- **Traefik v3** — L7 reverse proxy, TLS termination, health-check-based routing
- **CrowdSec** — community-driven intrusion prevention
- **MongoDB** — primary document store
- **Redis** — cache and message queue
- **Dozzle** — real-time container log viewer
- **Homepage** — service discovery dashboard

### Monitoring Stack
- **Grafana** — dashboards and alerting
- **VictoriaMetrics** — Prometheus-compatible time-series DB (better performance)
- **Loki** — log aggregation
- **Alertmanager** — alert routing and notification

### Automation Tooling
- **Constellation Agent** (`infra/`) — Go-based infrastructure agent; gossip cluster, Raft consensus, Traefik API provider, automated service failover

---

## Repo Layout

```
my-media-stack/
├── docker-compose.yml          # Core services (MongoDB, Redis, Dozzle, Homepage…)
├── compose/                    # Modular service groups (metrics, LLM, Coolify, L4…)
├── infra/                      # Constellation Agent — Go source + docs
│   └── docs/                   # 27 docs covering architecture, API, ops runbooks
├── docs/                       # Infrastructure architecture and operational docs (you are here)
├── scripts/                    # Maintenance and utility scripts
├── secrets/                    # Runtime secrets (excluded from git)
└── volumes/                    # Persistent data volumes
```

---

## Philosophy

This stack deliberately avoids orchestrators. The reasoning — and the costs of that choice — are explored in [The Hidden Attrition of Infrastructure](../plan-infrastructure-unification.md).

The short version: orchestrators like Kubernetes introduce a *control plane paradox* — the system that manages your services is itself a distributed system that can fail. For a homelab, the operational overhead outweighs the benefits. Instead, this infrastructure uses:

- Simple DNS-based failover (Cloudflare multi-A-record)
- Traefik as a lightweight mesh boundary
- A custom Go agent (Constellation) for gossip-based health tracking and automated routing updates
- Runbooks + automation scripts for operational tasks that would otherwise need an orchestrator

---

## Document Status

| Document | Status | Last Updated |
|---|---|---|
| [Infrastructure Master Plan](INFRASTRUCTURE_MASTER_PLAN.md) | Active | 2026-03-03 |
| [Orchestration Overview](../orchestration/README.md) | Active | 2026-06-04 |
| [Constellation Agent Docs](../infra/docs/README.md) | Active | Ongoing |
| [Orchestration Research 2026](orchestration_research_2026.md) | Research/Reference | 2026 |
| [Stateful HA Plan](stateful_ha_plan.md) | Planning | Active |
| [Maintenance Guide](MAINTENANCE.md) | Active | Ongoing |
| [KotorModSync Telemetry](KOTORMODSYNC_TELEMETRY_SETUP.md) | Active | Ongoing |

---

## Run The Knowledgebase

Use these commands from the repository root.

Start docs service with core stack:

```bash
docker compose up -d mkdocs
```

Validate merged compose config:

```bash
docker compose config --quiet
```

Watch logs:

```bash
docker logs -f mkdocs
```

Open the site:

- Routed host: `https://docs.$DOMAIN`
- Local host port: `http://localhost:8001`

Quick troubleshooting:

```bash
docker ps --filter "name=mkdocs" --format "table {{.Names}}\t{{.Status}}"
docker inspect mkdocs --format '{{json .State.Health}}'
docker compose up -d --force-recreate mkdocs
```
