# Constellation Agent API Reference

This document describes the APIs and interfaces provided by Constellation Agent.

## Traefik HTTP Provider API

The agent exposes an HTTP server that Traefik polls for dynamic configuration. This replaces file-based configuration with a programmatic API.

### Base URL

```
http://localhost:8081
```

### Endpoints

#### GET /api/http/routers

Returns HTTP/HTTPS routing rules for Traefik.

**Response Format:**
```json
{
  "service-node-direct": {
    "rule": "Host(`service.node.bolabaden.org`)",
    "service": "service-node-direct",
    "entryPoints": ["websecure"],
    "tls": {
      "certResolver": "letsencrypt"
    }
  },
  "service-with-failover": {
    "rule": "Host(`service.bolabaden.org`)",
    "service": "service-with-failover",
    "entryPoints": ["websecure"],
    "tls": {
      "certResolver": "letsencrypt"
    }
  }
}
```

**Router Fields:**
- `rule`: Traefik routing rule (Host, PathPrefix, etc.)
- `service`: Name of the service to route to
- `entryPoints`: List of entry points (web, websecure)
- `tls`: TLS configuration (optional)
- `middlewares`: List of middleware names (optional)
- `priority`: Router priority (optional)

#### GET /api/http/services

Returns backend service definitions.

**Response Format:**
```json
{
  "service-node-direct": {
    "loadBalancer": {
      "servers": [
        {"url": "http://service:8080"}
      ]
    }
  },
  "service-with-failover": {
    "loadBalancer": {
      "servers": [
        {"url": "https://service.node1.bolabaden.org"},
        {"url": "https://service.node2.bolabaden.org"}
      ],
      "healthCheck": {
        "path": "/",
        "interval": "30s",
        "timeout": "10s"
      },
      "method": "wrr"
    }
  }
}
```

**Service Fields:**
- `loadBalancer.servers`: List of backend server URLs
- `loadBalancer.healthCheck`: Health check configuration (optional)
- `loadBalancer.method`: Load balancing method (wrr, drr)
- `loadBalancer.sticky`: Sticky session configuration (optional)

#### GET /api/http/middlewares

Returns middleware configurations.

**Response Format:**
```json
{
  "middleware-name": {
    // Middleware-specific configuration
  }
}
```

Currently returns empty object `{}` as middlewares are defined via Traefik labels.

#### GET /api/tcp/routers

Returns TCP routing rules.

**Response Format:**
```json
{
  "tcp-service-router": {
    "rule": "HostSNI(`service.bolabaden.org`)",
    "service": "tcp-service",
    "entryPoints": ["tcp"]
  }
}
```

#### GET /api/tcp/services

Returns TCP backend service definitions.

**Response Format:**
```json
{
  "tcp-service": {
    "loadBalancer": {
      "servers": [
        {"address": "node1:6379"},
        {"address": "node2:6379"}
      ]
    }
  }
}
```

#### GET /api/udp/routers

Returns UDP routing rules.

**Response Format:**
```json
{
  "udp-service-router": {
    "entryPoints": ["udp"],
    "service": "udp-service"
  }
}
```

#### GET /api/udp/services

Returns UDP backend service definitions.

**Response Format:**
```json
{
  "udp-service": {
    "loadBalancer": {
      "servers": [
        {"address": "node1:53"},
        {"address": "node2:53"}
      ]
    }
  }
}
```

#### GET /health

Health check endpoint.

**Response:**
```
OK
```

**Status Codes:**
- `200 OK`: Agent is healthy
- `500 Internal Server Error`: Agent is unhealthy

#### GET /api/dynamic (Legacy)

Returns complete dynamic configuration (legacy endpoint for compatibility).

**Response Format:**
```json
{
  "http": {
    "routers": {...},
    "services": {...},
    "middlewares": {...}
  },
  "tcp": {
    "routers": {...},
    "services": {...}
  },
  "udp": {
    "routers": {...},
    "services": {...}
  }
}
```

### Configuration Generation

Configuration is generated from gossip state:

1. Agent queries `ClusterState` for all service health entries
2. Filters to only healthy services
3. Generates routers for:
   - Direct node access: `<service>.<node>.bolabaden.org`
   - Load balanced: `<service>.bolabaden.org`
4. Creates services pointing to healthy backends
5. Adds health checks from service metadata

### Caching

Configuration is cached for 5 seconds to reduce CPU usage. Traefik polls every 5 seconds, so this provides near real-time updates while avoiding excessive computation.

## Gossip State API

The gossip state is accessed internally by the agent. External access is available through the cluster state object.

### Node Metadata

```go
type NodeMetadata struct {
    Name         string
    PublicIP     string
    TailscaleIP  string
    Priority     int
    Capabilities []string
    LastSeen     time.Time
    Cordoned     bool
}
```

### Service Health

```go
type ServiceHealth struct {
    ServiceName string
    NodeName    string
    Healthy     bool
    CheckedAt   time.Time
    Endpoints   map[string]string
    Networks    []string
}
```

### WARP Health

```go
type WARPHealth struct {
    NodeName  string
    Healthy   bool
    CheckedAt time.Time
}
```

## Raft Consensus API

Raft operations are internal to the agent. The following operations are available:

### Lease Management

**Acquire LB Leader Lease:**
```go
err := leaseManager.AcquireLBLeaderLease()
```

**Acquire DNS Writer Lease:**
```go
err := leaseManager.AcquireDNSWriterLease()
```

**Release Lease:**
```go
leaseManager.ReleaseLease(leaseType)
```

**Get Lease:**
```go
lease := consensusManager.GetLease(leaseType)
```

### Leader Status

**Check if Leader:**
```go
isLeader := consensusManager.IsLeader()
```

**Get Leader Address:**
```go
leader := consensusManager.Leader()
```

## DNS Controller API

The DNS controller manages Cloudflare DNS records.

### Update LB Leader

Updates apex and wildcard records to point to the current LB leader.

```go
dnsController.UpdateLBLeader(publicIP)
```

### Update Node IPs

Updates per-node wildcard records.

```go
nodeIPs := map[string]string{
    "node1": "1.2.3.4",
    "node2": "5.6.7.8",
}
dnsController.UpdateNodeIPs(nodeIPs)
```

### Lease Ownership

Sets whether this node holds the DNS writer lease.

```go
dnsController.SetLeaseOwnership(hasLease)
```

## Service Deployment API

Services are deployed via the main deployment tool (`main.go`).

### Service Definition

```go
type Service struct {
    Name          string
    Image         string
    ContainerName string
    Hostname      string
    Networks      []string
    Ports         []PortMapping
    Volumes       []VolumeMount
    Environment   map[string]string
    Labels        map[string]string
    Command       []string
    Entrypoint    []string
    User          string
    Devices       []string
    Restart       string
    Healthcheck   *Healthcheck
    DependsOn     []string
    Privileged    bool
    CapAdd        []string
    MemLimit      string
    MemReservation string
    CPUs          string
    ExtraHosts    []string
    Build         *BuildConfig
    Secrets       []SecretMount
    Configs       []ConfigMount
}
```

### Deploying Services

```go
infra := NewInfrastructure(config)
err := infra.EnsureNetworks()
err := infra.DeployService(service)
```

## Network Management API

### Network Definition

```go
type NetworkConfig struct {
    Name       string
    Driver     string
    Subnet     string
    Gateway    string
    BridgeName string
    External   bool
    Attachable bool
}
```

### Network Assignment

Networks are assigned to services based on labels:

- `traefik.enable=true` → Adds `publicnet`
- `network.warp.enabled=true` → Adds `warp-nat-net`
- `network.backend.only=true` → Only `backend` network
- Default → `backend` network

## Health Monitoring API

### Service Health Monitoring

Services are monitored automatically. Health status is broadcast via gossip.

**Health Check:**
- Container state (running/stopped)
- Docker healthcheck status
- Service endpoints discovery
- Network assignment tracking

### WARP Health Monitoring

WARP gateway health is monitored and broadcast.

**Health Check:**
- Container running status
- Egress connectivity test
- IP verification (Cloudflare WARP range)

## Error Handling

### Gossip Errors

- Node not found: Returns empty metadata
- Unmarshal failure: Logs error, skips node
- State merge failure: Logs error, continues with local state

### Raft Errors

- Not leader: Returns error for lease operations
- Network failure: Attempts to rejoin cluster
- Log write failure: Returns error, retries

### DNS Errors

- API failure: Logs error, retries with backoff
- Rate limit: Waits and retries
- Invalid record: Logs error, skips update

### Traefik Provider Errors

- Config generation failure: Returns last known config
- Marshal failure: Returns empty config
- Server error: Logs error, continues serving

## Rate Limiting

### Cloudflare DNS API

- Rate limit: 4 requests per second
- Burst limit: 10 requests
- Automatic backoff on rate limit errors

### Gossip Protocol

- Gossip interval: 200ms
- Probe interval: 1 second
- Retransmit multiplier: 4

### Raft Consensus

- Heartbeat interval: 50ms
- Election timeout: 1-2 seconds
- Snapshot interval: Configurable

## Configuration

### Environment Variables

See [Configuration Guide](CONFIGURATION.md) for complete list.

### Command Line Flags

**Agent Flags:**
- `--domain`: Domain name (default: from env)
- `--node-name`: Node name (default: from TS_HOSTNAME)
- `--bind-addr`: Gossip bind address (default: Tailscale IP)
- `--bind-port`: Gossip port (default: 7946)
- `--raft-port`: Raft port (default: 8300)
- `--data-dir`: Raft data directory (default: /opt/constellation/data)
- `--config-path`: Service volumes path (default: /opt/constellation/volumes)
- `--secrets-path`: Secrets path (default: /opt/constellation/secrets)
- `--http-provider-port`: HTTP provider port (default: 8081)

## Examples

### Querying Service Health

```go
state := gossipCluster.GetState()
health, exists := state.GetServiceHealth("my-service", "node1")
if exists && health.Healthy {
    // Service is healthy
}
```

### Getting All Healthy Services

```go
state := gossipCluster.GetState()
healthyNodes := state.GetHealthyServiceNodes("my-service")
// Returns: ["node1", "node2"]
```

### Checking WARP Health

```go
state := gossipCluster.GetState()
warpHealth, exists := state.GetWARPHealth("node1")
if exists && warpHealth.Healthy {
    // WARP gateway is healthy
}
```

### Testing HTTP Provider

```bash
# Get HTTP routers
curl http://localhost:8081/api/http/routers

# Get HTTP services
curl http://localhost:8081/api/http/services

# Health check
curl http://localhost:8081/health
```

## Best Practices

### Service Labels

Use consistent label naming:
- `traefik.enable=true` for services behind Traefik
- `deunhealth.restart.on.unhealthy=true` for auto-restart
- `kuma.<service>.http.name` for Kuma monitoring
- `homepage.*` for homepage integration

### Health Checks

Always define health checks:
- Use HTTP checks when possible
- Set appropriate intervals (10-30s)
- Include start period for slow services
- Test actual service functionality, not just port

### Network Assignment

- Use `backend` for internal services
- Use `publicnet` for services behind Traefik
- Use `warp-nat-net` only when anonymous egress needed
- Avoid unnecessary network assignments

### Error Handling

- Log errors with context
- Retry transient failures
- Fail fast on permanent errors
- Provide actionable error messages

