# Copilot Instructions for bolabaden-infra

## Overview
This codebase powers **bolabaden.org**, a multi-node Docker-based infrastructure designed for high availability WITHOUT orchestrators like Kubernetes or Docker Swarm. Understanding the "no-cluster" philosophy and distributed service architecture is critical for effective contributions.

## Architecture Philosophy

### Multi-Node Without Orchestration
- **No central orchestrator**: Services are manually assigned to nodes; the system reflects current state, not desired state
- **Distributed failover**: Each node can independently serve requests or forward to peers
- **Service registry**: Simple YAML file (`services.yaml`) synced across nodes lists what services run where
- **L7 Reverse Proxy**: Traefik v3 with file provider handles HTTP(S) routing with health checks and primary+fallback configs
- **L4 Proxy**: For raw TCP services (Redis, MongoDB, etc.)
- **DNS failover**: Cloudflare with multiple A records provides node-level failover

### Request Flow Pattern
```
User → Cloudflare DNS → Any Node
  ├─ Service exists locally? → Serve directly (fast path)
  └─ Service on another node? → Proxy via Traefik → Serve from peer node
```

This ensures requests always succeed regardless of which node they hit.

## Critical File Structure

### Docker Compose Organization
- **Main file**: `docker-compose.yml` - Core services (MongoDB, Redis, Dozzle, Homepage, etc.)
- **Compose includes**: `compose/docker-compose.*.yml` - Modular service groups
  - `compose/docker-compose.metrics.yml` - Complete monitoring stack (Grafana, Prometheus, VictoriaMetrics, Loki)
  - `compose/docker-compose.stremio-group.yml` - Media services
  - `compose/docker-compose.llm.yml` - AI/LLM services
  - `compose/docker-compose.coolify-proxy.yml` - Coolify integration
  
### Configuration Patterns

#### ALWAYS Inline Configs (Preferred)
```yaml
configs:
  example-config:
    content: |
      multiline
      config
      content
```

**Why inline?**
- Single source of truth
- Easier git diffs and reviews
- No file path resolution issues
- Simpler deployments

#### Dollar Sign Escaping in Configs
```yaml
configs:
  grafana.ini:
    content: |
      # Double $$ = literal $ in output
      instance_name = $$HOSTNAME
      # Single $ = Docker Compose variable substitution
      port = ${GRAFANA_PORT:-3000}
```

### Networks Architecture
- **publicnet**: Public-facing services (Traefik, Grafana, etc.)
- **backend**: Internal communication (databases, message queues)
- **warp-nat-net**: Special network for Cloudflare WARP routing

### Service Naming Conventions
- Container names match hostnames: `container_name: grafana` → `hostname: grafana`
- Services expose internal ports (not published to host) and rely on Traefik for external access
- Traefik labels define routing: `traefik.http.routers.grafana.rule: Host(\`grafana.$DOMAIN\`)`

## Developer Workflows

### Building and Testing
```bash
# Build and start all services
docker compose up -d --remove-orphans --force-recreate --pull=always --build

# Start specific service group
docker compose -f docker-compose.yml -f compose/docker-compose.metrics.yml up -d

# Check service health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Adding New Services
1. Choose appropriate compose file (`docker-compose.yml` or a modular `compose/*.yml`)
2. Define service with:
   - Proper network attachments (`publicnet` and/or `backend`)
   - Traefik labels if web-accessible
   - Comprehensive healthcheck (REQUIRED - see below)
   - Homepage labels for dashboard integration
   - Prometheus scrape labels if applicable
3. Update `services.yaml` registry if multi-node
4. Test locally before deploying

### Healthcheck Requirements (MANDATORY)
**NEVER disable or remove healthchecks.** Every service MUST have:

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
labels:
  deunhealth.restart.on.unhealthy: "true"  # Auto-restart on failure
```

**Bad healthchecks to avoid:**
- TCP-only checks (`nc -z`)
- Disabled healthchecks
- Missing `start_period` (causes false failures during startup)

### Debugging Common Issues

#### Service Not Accessible
1. Check Traefik dashboard: `https://traefik.bolabaden.org`
2. Verify service is healthy: `docker ps | grep <service>`
3. Check Traefik labels on service: `docker inspect <service> | grep traefik`
4. Review Traefik logs: `docker logs traefik`

#### Container Keeps Restarting
1. Check healthcheck status: `docker inspect <service> --format='{{.State.Health.Status}}'`
2. View container logs: `docker logs <service> --tail=100`
3. Check resource limits: Service may be OOM killed
4. Review startup timing: Increase `start_period` if needed

#### Disk Space Issues
This repo includes automated maintenance (`scripts/docker-maintenance.sh`):
```bash
# Manual cleanup
sudo ./scripts/docker-maintenance.sh

# Emergency cleanup (interactive)
./scripts/emergency-cleanup.sh

# Check disk usage
df -h /
docker system df
```

Common space hogs:
- Docker overlay2 (use `docker system prune -a`)
- Container logs (configured in `/etc/docker/daemon.json`)
- Prometheus WAL, Stremio cache, application data

## Project-Specific Patterns

### Monitoring Stack (compose/docker-compose.metrics.yml)
- **Grafana**: Dashboards inlined as configs (see `alert-overview.json`, `container-monitoring.json`, etc.)
- **VictoriaMetrics**: Drop-in Prometheus replacement with better performance
- **Loki**: Log aggregation
- **Alertmanager**: Alert routing and notification
- All dashboards provisioned via configs, not external files

### Service Discovery Pattern
```yaml
# services.yaml (distributed to all nodes)
http:
  dozzle.bolabaden.org:
    backends:
      - host: node1.bolabaden.org
        port: 8080
      - host: node3.bolabaden.org
        port: 8080
tcp:
  redis-main:
    port: 6379
    backends:
      - host: node1.bolabaden.org
        port: 6379
```

### Traefik Integration
Services use labels for auto-discovery:
```yaml
labels:
  traefik.enable: true
  traefik.http.routers.myservice.rule: Host(`myservice.$DOMAIN`)
  traefik.http.services.myservice.loadbalancer.server.port: 8080
  # Health check (Traefik pings this to verify service health)
  traefik.http.services.myservice.loadbalancer.healthcheck.path: /health
  traefik.http.services.myservice.loadbalancer.healthcheck.interval: 30s
```

### Homepage Dashboard Integration
```yaml
labels:
  homepage.group: Infrastructure
  homepage.name: My Service
  homepage.icon: myservice.png
  homepage.href: https://myservice.$DOMAIN
  homepage.description: Service description
```

### Secrets Management
- Secrets stored in `${SECRETS_PATH}/` (environment variable)
- Declared in compose:
```yaml
secrets:
  my-secret:
    file: ${SECRETS_PATH:?}/my-secret.txt
services:
  myservice:
    secrets:
      - my-secret
```

## Integration Points

### DNS Configuration
- **Provider**: Cloudflare
- **Pattern**: Multiple A records for `*.bolabaden.org` pointing to each node
- **DDNS**: Each node updates its own A record via Cloudflare API

### External Dependencies
- **Cloudflare**: DNS and CDN
- **Tailscale**: Secure node-to-node communication (optional)
- **Coolify**: Self-hosted PaaS integration for some services

### Cross-Component Communication
- Services communicate via Docker networks (no hardcoded IPs)
- Use container/service names as hostnames: `redis://redis:6379`
- Traefik provides service mesh-like routing without complexity

## Common Pitfalls & Solutions

### Don't: Hardcode IPs or Ports
```yaml
# ❌ Bad
environment:
  DATABASE_URL: "postgres://10.0.7.5:5432/db"

# ✅ Good
environment:
  DATABASE_URL: "postgres://postgres:5432/db"
```

### Don't: Skip Healthchecks
Every service needs proper health validation. If a service lacks `curl` or `wget`:
```yaml
healthcheck:
  test: ["CMD-SHELL", "apk add --no-cache wget && wget --spider http://127.0.0.1:8080/health || exit 1"]
```

### Don't: Use External Config Files
Inline everything in compose configs sections - makes the setup portable and reviewable.

### Do: Use Environment Variables
```yaml
environment:
  PORT: ${SERVICE_PORT:-8080}
  LOG_LEVEL: ${LOG_LEVEL:-info}
```

### Do: Tag Services for Observability
```yaml
labels:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
  kuma.myservice.http.name: "myservice.$DOMAIN"
  kuma.myservice.http.url: "https://myservice.$DOMAIN"
```

## Testing Checklist

Before considering changes complete:
- [ ] All services have comprehensive healthchecks
- [ ] Service accessible via Traefik (if web service)
- [ ] Healthcheck passes: `docker ps` shows "(healthy)"
- [ ] Logs show no errors: `docker logs <service>`
- [ ] Service appears in Homepage dashboard
- [ ] Prometheus scraping works (if applicable)
- [ ] Changes committed to git with conventional commit message
- [ ] `docker compose config` validates without errors

## Git Workflow (MANDATORY)

Every change MUST be committed:
```bash
git add <files>
git commit -m "type: description"
```

Use conventional commit types:
- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code refactoring
- `docs:` - Documentation
- `chore:` - Maintenance

## Summary

This infrastructure prioritizes:
1. **Simplicity**: No orchestrators, just Docker Compose
2. **Resilience**: Multi-node with automatic failover
3. **Observability**: Comprehensive monitoring and logging
4. **Maintainability**: Everything in version control, configs inlined

When in doubt, follow existing patterns in the compose files. The system is designed to be understandable by reading the compose definitions alone.