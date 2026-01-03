# Infrastructure as Code - Go + Docker SDK

This is a complete replacement for `docker-compose.yml` using Go and the Docker SDK. It provides:

- **Imperative code** instead of declarative YAML
- **Zero SPOF** with automatic failover
- **Dynamic service discovery** via Tailscale
- **Self-contained** - no external YAML references
- **HA load balancing** for both HTTP (Traefik) and TCP (HAProxy)

## Architecture

### URL Structure
- `<service>.<node_name>.bolabaden.org` → Always resolves to that service on that specific node
- `<service>.bolabaden.org` → Load balances across all nodes running that service with automatic fallback

### Components

1. **Tailscale Discovery** (`tailscale.go`)
   - Discovers all cluster nodes via `tailscale status --json`
   - Maps node names to Tailscale IPs
   - Prioritizes fast nodes (micklethefickle, beatapostapita) over slow ones (cloudserver1-3)

2. **Docker Network Management** (`main.go`)
   - Creates all required Docker networks
   - Handles external networks (warp-nat-net)
   - Configures bridge names and IPAM

3. **Service Deployment** (`main.go`, `services.go`)
   - Deploys all containers from docker-compose.yml
   - Handles volumes, ports, environment variables
   - Manages healthchecks and restart policies

4. **Traefik Dynamic Config** (`traefik.go`)
   - Generates `failover-fallbacks.yaml` dynamically
   - Creates routers for both node-specific and global hostnames
   - Implements health-checked failover

5. **HAProxy L4 Config** (`haproxy.go`)
   - Generates TCP load balancer config
   - Uses Tailscale IPs exclusively (no DNS dependency)
   - Supports protocol-aware healthchecks (Redis, TCP)

## Usage

```bash
cd infra
go mod download
go build -o deploy
sudo ./deploy
```

## Environment Variables

- `DOMAIN` - Your domain (default: `bolabaden.org`)
- `STACK_NAME` - Docker stack name (default: `my-media-stack`)
- `CONFIG_PATH` - Path to volumes/config (default: `./volumes`)
- `ROOT_PATH` - Project root (default: `.`)
- `SECRETS_PATH` - Path to secrets (default: `./secrets`)
- `TS_HOSTNAME` - Current node's Tailscale hostname

## Service Labels

### HTTP Services (Traefik)
- `traefik.enable=true` - Enable Traefik routing
- `traefik.http.services.<name>.loadbalancer.server.port=<port>` - Service port
- `kuma.healthcheck.path` - Healthcheck path (default: `/`)
- `kuma.healthcheck.interval` - Healthcheck interval (default: `30s`)

### TCP Services (HAProxy)
- `osvc.l4.enable=true` - Enable L4 load balancing
- `osvc.l4.port=<port>` - TCP port to expose
- `osvc.l4.check=tcp|redis` - Healthcheck type

## Zero SPOF Strategy

1. **Stateless Services**: Run multiple instances across nodes, Traefik load balances
2. **Stateful Services**: 
   - MongoDB: Replica set (future)
   - Redis: Sentinel/Cluster (future)
   - Postgres: Streaming replication (future)
3. **Ingress**: Multiple Traefik instances, DNS round-robin
4. **L4 Load Balancing**: HAProxy with healthchecks, automatic failover

## Migration from docker-compose.yml

All services from `docker-compose.yml` and `compose/*.yml` are defined in `services.go`. The structure is 1:1 equivalent but in Go code.

## Next Steps

1. Complete all service definitions from docker-compose.yml
2. Implement stateful HA (MongoDB replica set, Redis Sentinel)
3. Add volume management for stateful services
4. Implement image building for services with `build:` directives
5. Add dependency resolution and startup ordering

