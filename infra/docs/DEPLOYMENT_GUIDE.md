# Constellation Agent - Deployment Guide

## Overview

The Constellation Agent is a zero-SPOF, gossip-based high-availability orchestration system for Docker containers. It provides:

- **Gossip-based service discovery** using HashiCorp Memberlist
- **Raft consensus** for leader election and critical operations
- **Dynamic Traefik configuration** via HTTP provider API
- **Automatic DNS management** via Cloudflare API
- **Self-healing** service health monitoring
- **WARP network monitoring** for anonymous egress

## Prerequisites

### System Requirements

- Linux system with systemd
- Docker Engine 24.0+ (API version 1.44+)
- Go 1.24+ (for building)
- Tailscale installed and configured
- Network access to:
  - Cloudflare API (for DNS updates)
  - Other cluster nodes (via Tailscale)
  - Public IP detection services (ipify, ifconfig.me, etc.)

### Node Configuration

Each node should have:
- Unique hostname (used as node name)
- Tailscale configured with unique hostname
- Public IP address (or PUBLIC_IP environment variable)
- Docker daemon running

### Required Secrets

Create the following files in `/opt/constellation/secrets/`:

- `cf-api-token.txt` - Cloudflare API token with DNS edit permissions

### Environment Variables

Set in systemd service or environment:

- `TS_HOSTNAME` - Tailscale hostname (defaults to system hostname)
- `DOMAIN` - Domain name for services (default: `bolabaden.org`)
- `PUBLIC_IP` - Public IP address (auto-detected if not set)
- `CONFIG_PATH` - Path for service volumes (default: `/opt/constellation/volumes`)
- `SECRETS_PATH` - Path for secrets (default: `/opt/constellation/secrets`)
- `DATA_DIR` - Path for Raft data (default: `/opt/constellation/data`)
- `CLOUDFLARE_ZONE_ID` - Cloudflare zone ID for DNS updates

## Installation

### Step 1: Build and Install Agent

```bash
cd /path/to/my-media-stack/infra
./scripts/install.sh
```

This will:
- Build the agent binary to `/usr/local/bin/constellation-agent`
- Create required directories
- Install systemd service

### Step 2: Configure Secrets

```bash
# Create secrets directory
mkdir -p /opt/constellation/secrets

# Add Cloudflare API token
echo "your-cloudflare-api-token" > /opt/constellation/secrets/cf-api-token.txt
chmod 600 /opt/constellation/secrets/cf-api-token.txt
```

### Step 3: Configure Environment

Edit `/etc/systemd/system/constellation-agent.service` to set:

```ini
Environment=CLOUDFLARE_ZONE_ID=your-zone-id
Environment=DOMAIN=bolabaden.org
Environment=PUBLIC_IP=your-public-ip  # Optional, auto-detected
```

### Step 4: Start Agent

```bash
systemctl daemon-reload
systemctl start constellation-agent
systemctl enable constellation-agent
```

### Step 5: Verify Installation

```bash
# Check service status
systemctl status constellation-agent

# View logs
journalctl -u constellation-agent -f

# Verify agent is running
ps aux | grep constellation-agent
```

## Cluster Setup

### First Node (Bootstrap)

1. Install agent on first node
2. Start agent - it will bootstrap the cluster
3. Verify logs show:
   - "Initializing gossip cluster..."
   - "Initializing Raft consensus..."
   - "Constellation Agent started successfully"

### Additional Nodes

1. Install agent on each additional node
2. Ensure Tailscale connectivity to existing nodes
3. Start agent - it will automatically discover peers via Tailscale
4. Verify logs show successful peer discovery

### Node Priority

Nodes are prioritized by name:
- Nodes with "cloudserver" in name: Priority 10 (higher priority)
- Other nodes: Priority 50 (lower priority)

Lower priority number = higher priority for leader election.

## Service Deployment

### Deploy Services via main.go

The main deployment tool (`infra/main.go`) deploys services defined in Go:

```bash
cd /path/to/my-media-stack/infra
go run main.go
```

This will:
- Create required Docker networks (backend, publicnet, warp-nat-net)
- Deploy all services defined in `services*.go` files
- Assign services to appropriate networks
- Set up healthchecks and labels

### Service Discovery

Once services are deployed, the agent will:
- Monitor service health via Docker API
- Broadcast health status via gossip
- Update Traefik configuration dynamically
- Update DNS records for healthy services

## Traefik Configuration

### Static Configuration

Traefik needs static configuration to use the HTTP provider:

```yaml
# traefik.yml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  http:
    endpoint: "http://localhost:8081"
    pollInterval: 5s

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /data/acme.json
      httpChallenge:
        entryPoint: web
```

### Dynamic Configuration

The agent serves dynamic configuration at `http://localhost:8081/api/http/routers` and `/api/http/services`.

Traefik automatically polls this endpoint and updates routing.

## DNS Management

### Automatic DNS Updates

The agent automatically:
- Updates apex domain (`bolabaden.org`) to point to LB leader
- Updates wildcard (`*.bolabaden.org`) to point to LB leader
- Updates per-node wildcards (`*.node.bolabaden.org`) to point to each node

### DNS Leader Election

Only one node (the DNS writer lease holder) performs DNS updates to prevent conflicts.

### Manual DNS Updates

If needed, DNS can be updated manually via Cloudflare dashboard or API.

## Monitoring

### Service Health

Service health is monitored every 10 seconds:
- Container state (running/stopped)
- Docker healthcheck status
- Service endpoints and networks

### WARP Health

WARP gateway health is monitored every 30 seconds:
- Container running status
- Egress connectivity test

### Gossip State

View current cluster state:
- All nodes and their status
- All services and their health
- WARP health status

### Raft Consensus

Raft state is stored in `/opt/constellation/data/raft/`:
- `logs/` - Raft log entries
- `stable/` - Stable store
- `snapshots/` - Raft snapshots

## Troubleshooting

### Agent Won't Start

1. Check Docker is running: `systemctl status docker`
2. Check Tailscale is connected: `tailscale status`
3. Check logs: `journalctl -u constellation-agent -n 100`
4. Verify secrets exist: `ls -la /opt/constellation/secrets/`

### Services Not Discovered

1. Verify services are running: `docker ps`
2. Check service health monitoring: `journalctl -u constellation-agent | grep "service health"`
3. Verify gossip connectivity: Check logs for peer discovery

### DNS Not Updating

1. Verify DNS writer lease: Check logs for "acquired DNS writer lease"
2. Check Cloudflare API token: Verify token has DNS edit permissions
3. Check zone ID: Verify `CLOUDFLARE_ZONE_ID` is set correctly
4. Check rate limits: Cloudflare has rate limits on API calls

### Traefik Not Getting Config

1. Verify HTTP provider is running: `curl http://localhost:8081/api/http/routers`
2. Check Traefik logs: `docker logs traefik`
3. Verify Traefik static config includes HTTP provider
4. Check agent logs for HTTP provider errors

### Raft Consensus Issues

1. Check Raft data directory: `ls -la /opt/constellation/data/raft/`
2. Verify network connectivity between nodes
3. Check for split-brain scenarios (multiple leaders)
4. Review Raft logs in data directory

## Maintenance

### Updating Agent

1. Stop agent: `systemctl stop constellation-agent`
2. Rebuild: `cd infra && go build -o /usr/local/bin/constellation-agent ./cmd/agent`
3. Start agent: `systemctl start constellation-agent`

### Backup

Important data to backup:
- `/opt/constellation/data/raft/` - Raft consensus state
- `/opt/constellation/secrets/` - Secrets (encrypted backup recommended)
- Service volumes in `/opt/constellation/volumes/`

### Scaling

To add a new node:
1. Install agent on new node
2. Ensure Tailscale connectivity
3. Start agent - it will auto-join cluster
4. Deploy services to new node

To remove a node:
1. Stop services on node
2. Stop agent: `systemctl stop constellation-agent`
3. Remove from cluster (other nodes will detect via gossip)

## Security Considerations

1. **Secrets**: Store secrets securely, use encrypted backups
2. **Network**: Use Tailscale for secure inter-node communication
3. **API Tokens**: Rotate Cloudflare API tokens regularly
4. **Firewall**: Restrict access to agent HTTP provider (port 8081)
5. **Docker**: Run containers with least privilege
6. **Systemd**: Service runs as root (required for Docker access)

## Performance Tuning

### Gossip Settings

Default gossip port: 7946
- Adjust `bind-port` if port conflicts
- Increase `bind-addr` timeout for slow networks

### Raft Settings

Default Raft port: 8300
- Adjust `raft-port` if port conflicts
- Increase timeout for slow networks

### Health Check Intervals

- Service health: 10 seconds (configurable in code)
- WARP health: 30 seconds (configurable in code)
- DNS reconciliation: 60 seconds (configurable in code)

## Support

For issues or questions:
1. Check logs: `journalctl -u constellation-agent -f`
2. Review this guide
3. Check code comments in source files
4. Review plan document: `.cursor/plans/zero-spof_gossip_ha_e844e8e2.plan.md`

