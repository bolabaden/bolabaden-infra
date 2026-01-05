# Configuration Guide

This guide covers all configuration options for Constellation Agent, from environment variables to service definitions.

## Environment Variables

### Required Variables

These must be set for the agent to function:

**`TS_HOSTNAME`**
- Description: Tailscale hostname for this node
- Default: System hostname
- Example: `beatapostapita`
- Used for: Node identification, DNS record creation

**`DOMAIN`**
- Description: Base domain for all services
- Default: `bolabaden.org`
- Example: `example.com`
- Used for: DNS records, Traefik routing rules

**`CLOUDFLARE_ZONE_ID`**
- Description: Cloudflare zone ID for DNS updates
- Default: None (required)
- Example: `abc123def456`
- Used for: DNS record management

### Optional Variables

**`PUBLIC_IP`**
- Description: Public IP address of this node
- Default: Auto-detected via external services
- Example: `1.2.3.4`
- Used for: DNS record updates
- Auto-detection: Tries multiple services (ifconfig.me, ipify.org, etc.)

**`CONFIG_PATH`**
- Description: Base path for service volumes and configs
- Default: `/opt/constellation/volumes`
- Example: `/data/constellation`
- Used for: Volume mounts, config files

**`SECRETS_PATH`**
- Description: Path to secrets directory
- Default: `/opt/constellation/secrets`
- Example: `/etc/constellation/secrets`
- Used for: Secret file mounts
- Security: Should have 600 permissions

**`DATA_DIR`**
- Description: Path for Raft data storage
- Default: `/opt/constellation/data`
- Example: `/var/lib/constellation`
- Used for: Raft logs, snapshots, stable store

**`STACK_NAME`**
- Description: Stack name for network prefixing
- Default: Empty (no prefix)
- Example: `my-media-stack`
- Used for: Docker network naming (e.g., `my-media-stack_publicnet`)

**`TRAEFIK_DOCKER_HOST`**
- Description: Docker socket path for Traefik
- Default: `unix:///var/run/docker.sock`
- Example: `tcp://docker-proxy:2375`
- Used for: Traefik Docker provider

**`DOCKER_SOCKET`**
- Description: Docker socket path for agent
- Default: `/var/run/docker.sock`
- Example: `/var/run/docker.sock`
- Used for: Docker API access

### Network Configuration

**`BACKEND_SUBNET`**
- Description: Subnet for backend network
- Default: `10.0.7.0/24`
- Example: `192.168.1.0/24`
- Used for: Backend network IPAM

**`BACKEND_GATEWAY`**
- Description: Gateway IP for backend network
- Default: `10.0.7.1`
- Example: `192.168.1.1`
- Used for: Backend network routing

**`PUBLICNET_SUBNET`**
- Description: Subnet for publicnet network
- Default: `10.76.0.0/16`
- Example: `172.16.0.0/16`
- Used for: Publicnet network IPAM

**`PUBLICNET_GATEWAY`**
- Description: Gateway IP for publicnet network
- Default: `10.76.0.1`
- Example: `172.16.0.1`
- Used for: Publicnet network routing

**`WARP_NAT_NET_SUBNET`**
- Description: Subnet for WARP network
- Default: `10.0.2.0/24`
- Example: `10.0.3.0/24`
- Used for: WARP network IPAM

**`WARP_NAT_NET_GATEWAY`**
- Description: Gateway IP for WARP network
- Default: `10.0.2.1`
- Example: `10.0.3.1`
- Used for: WARP network routing

### Gossip Configuration

**`GOSSIP_BIND_ADDR`**
- Description: Address to bind gossip protocol
- Default: Tailscale IP
- Example: `100.64.1.1`
- Used for: Memberlist bind address

**`GOSSIP_BIND_PORT`**
- Description: Port for gossip protocol
- Default: `7946`
- Example: `7947`
- Used for: Memberlist bind port

**`GOSSIP_ADVERTISE_ADDR`**
- Description: Address to advertise to other nodes
- Default: Tailscale IP
- Example: `100.64.1.1`
- Used for: Memberlist advertise address

### Raft Configuration

**`RAFT_BIND_ADDR`**
- Description: Address to bind Raft protocol
- Default: Tailscale IP
- Example: `100.64.1.1`
- Used for: Raft bind address

**`RAFT_BIND_PORT`**
- Description: Port for Raft protocol
- Default: `8300`
- Example: `8301`
- Used for: Raft bind port

**`RAFT_DATA_DIR`**
- Description: Path for Raft data (overrides DATA_DIR/raft)
- Default: `{DATA_DIR}/raft`
- Example: `/var/lib/constellation/raft`
- Used for: Raft logs and snapshots

### HTTP Provider Configuration

**`HTTP_PROVIDER_PORT`**
- Description: Port for Traefik HTTP provider API
- Default: `8081`
- Example: `9081`
- Used for: Traefik configuration endpoint

**`HTTP_PROVIDER_BIND_ADDR`**
- Description: Address to bind HTTP provider
- Default: `127.0.0.1`
- Example: `0.0.0.0`
- Used for: HTTP provider server

### Service-Specific Variables

Many services have their own environment variables. See individual service definitions in `services*.go` files.

Common patterns:
- `{SERVICE}_PORT`: Service port
- `{SERVICE}_HOST`: Service hostname
- `{SERVICE}_URL`: Service URL
- `{SERVICE}_PASSWORD`: Service password (use secrets)

## Secrets Management

Secrets are stored as files in the `SECRETS_PATH` directory.

### Required Secrets

**`cf-api-token.txt`**
- Description: Cloudflare API token
- Permissions: `600`
- Used for: DNS record updates
- Format: Plain text token

**`cf-api-key.txt`** (Alternative)
- Description: Cloudflare API key (legacy)
- Permissions: `600`
- Used for: DNS record updates (if token not available)
- Format: Plain text key

### Service Secrets

Services may require additional secrets. Check service definitions for required secret files.

Common secrets:
- `openai-api-key.txt`: OpenAI API key
- `firecrawl-api-key.txt`: Firecrawl API key
- Database passwords
- OAuth tokens

### Secret File Format

Secrets are plain text files. No special formatting required. Trailing newlines are stripped automatically.

Example:
```bash
echo "your-secret-value" > /opt/constellation/secrets/my-secret.txt
chmod 600 /opt/constellation/secrets/my-secret.txt
```

## Service Configuration

Services are defined in Go code in `services*.go` files. Each service is a `Service` struct.

### Basic Service Definition

```go
Service{
    Name:          "my-service",
    Image:         "docker.io/my/image:latest",
    ContainerName: "my-service",
    Hostname:      "my-service",
    Networks:      []string{"backend"},
    Restart:       "always",
}
```

### Network Assignment

Networks are assigned based on labels or explicit configuration:

**Automatic Assignment (via labels):**
- `traefik.enable=true` → Adds `publicnet`
- `network.warp.enabled=true` → Adds `warp-nat-net`
- `network.backend.only=true` → Only `backend` network
- Default → `backend` network

**Explicit Assignment:**
```go
Networks: []string{"backend", "publicnet"},
```

### Port Mapping

```go
Ports: []PortMapping{
    {HostPort: "8080", ContainerPort: "8080", Protocol: "tcp"},
    {HostPort: "443", ContainerPort: "443", Protocol: "udp"},
},
```

### Volume Mounts

```go
Volumes: []VolumeMount{
    {
        Source: "/data/my-service",
        Target: "/app/data",
        Type:   "bind",
    },
    {
        Source: "my-volume",
        Target: "/app/storage",
        Type:   "volume",
    },
},
```

### Environment Variables

```go
Environment: map[string]string{
    "NODE_ENV": "production",
    "PORT":     "8080",
    "HOST":     "0.0.0.0",
},
```

### Labels

Labels are used for Traefik routing, health monitoring, and service discovery:

```go
Labels: map[string]string{
    "traefik.enable": "true",
    "traefik.http.routers.my-service.rule": "Host(`my-service.example.com`)",
    "traefik.http.services.my-service.loadbalancer.server.port": "8080",
    "deunhealth.restart.on.unhealthy": "true",
    "kuma.my-service.http.name": "my-service.node.example.com",
    "kuma.my-service.http.url": "https://my-service.example.com",
    "kuma.my-service.http.interval": "60",
},
```

### Health Checks

```go
Healthcheck: &Healthcheck{
    Test:        []string{"CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"},
    Interval:    "30s",
    Timeout:     "10s",
    Retries:     3,
    StartPeriod: "30s",
},
```

### Secrets

```go
Secrets: []SecretMount{
    {
        Source: "/opt/constellation/secrets/my-secret.txt",
        Target: "/run/secrets/my-secret",
        Mode:   "0400",
    },
},
```

### Configs

```go
Configs: []ConfigMount{
    {
        Source: "my-config",
        Target: "/etc/my-service/config.yaml",
        Mode:   "0444",
        Content: "config content here",
    },
},
```

## Traefik Configuration

Traefik is configured via labels on services. The HTTP provider generates dynamic configuration from these labels.

### Basic Routing

```go
Labels: map[string]string{
    "traefik.enable": "true",
    "traefik.http.routers.my-service.rule": "Host(`my-service.example.com`)",
    "traefik.http.services.my-service.loadbalancer.server.port": "8080",
},
```

### TLS Configuration

```go
Labels: map[string]string{
    "traefik.http.routers.my-service.tls": "true",
    "traefik.http.routers.my-service.tls.certresolver": "letsencrypt",
},
```

### Middleware

```go
Labels: map[string]string{
    "traefik.http.routers.my-service.middlewares": "auth,rate-limit",
},
```

### Load Balancing

```go
Labels: map[string]string{
    "traefik.http.services.my-service.loadbalancer.method": "wrr",
    "traefik.http.services.my-service.loadbalancer.sticky": "true",
},
```

## Network Configuration

### Default Networks

Three networks are created by default:

1. **backend**: Internal communication
   - Subnet: `10.0.7.0/24`
   - Gateway: `10.0.7.1`
   - Driver: `bridge`

2. **publicnet**: External-facing services
   - Subnet: `10.76.0.0/16`
   - Gateway: `10.76.0.1`
   - Driver: `bridge`

3. **warp-nat-net**: Anonymous egress
   - Subnet: `10.0.2.0/24`
   - Gateway: `10.0.2.1`
   - Driver: `bridge`
   - IP masquerade: Disabled

### Custom Networks

Define custom networks in `main.go`:

```go
config.Networks["my-network"] = NetworkConfig{
    Name:       "my-network",
    Driver:     "bridge",
    Subnet:     "192.168.1.0/24",
    Gateway:    "192.168.1.1",
    Attachable: true,
}
```

## Gossip Configuration

Gossip protocol settings are tuned for Tailscale networks:

- TCP Timeout: 10 seconds
- Indirect Checks: 3
- Retransmit Multiplier: 4
- Suspicion Multiplier: 4
- Probe Interval: 1 second
- Probe Timeout: 500ms
- Gossip Interval: 200ms
- Gossip Nodes: 3

These can be adjusted in `cluster/gossip/memberlist.go` if needed.

## Raft Configuration

Raft consensus settings:

- Heartbeat Timeout: 50ms
- Election Timeout: 1-2 seconds
- Snapshot Interval: Configurable
- Log Retention: Configurable

These can be adjusted in `cluster/raft/consensus.go` if needed.

## DNS Configuration

### Cloudflare DNS

DNS records are managed automatically:

- Apex record (`example.com`) → Points to LB leader
- Wildcard (`*.example.com`) → Points to LB leader
- Per-node wildcard (`*.<node>.example.com`) → Points to node's public IP

### DNS Update Behavior

- Updates batched and rate limited
- Only DNS writer lease holder updates DNS
- Automatic failover if lease holder fails
- Drift correction every 60 seconds

## Health Check Configuration

### Service Health Checks

- Check interval: 10 seconds
- Health status broadcast via gossip
- Unhealthy services removed from routing
- Automatic restart if `deunhealth.restart.on.unhealthy=true`

### WARP Health Checks

- Check interval: 30 seconds
- Tests egress connectivity
- Verifies Cloudflare WARP IP
- Broadcasts health via gossip

## Performance Tuning

### Gossip Performance

- Reduce gossip interval for faster updates (but higher CPU)
- Increase gossip nodes for better propagation (but more network)
- Adjust probe interval based on network latency

### Raft Performance

- Reduce heartbeat timeout for faster leader detection
- Increase snapshot interval for less disk I/O
- Adjust election timeout based on network conditions

### HTTP Provider Performance

- Config cached for 5 seconds
- Traefik polls every 5 seconds
- Adjust cache duration if needed

## Security Configuration

### Secret Permissions

All secrets should have `600` permissions:
```bash
chmod 600 /opt/constellation/secrets/*
```

### Network Security

- Use Tailscale for inter-node communication
- Firewall HTTP provider port (only Traefik should access)
- Restrict Docker socket access
- Use read-only mounts where possible

### Container Security

- Run containers with least privilege
- Use `User` field to run as non-root
- Avoid `Privileged: true` unless necessary
- Use `CapAdd` sparingly

## Troubleshooting Configuration

### Debug Mode

Set log level to DEBUG (if implemented):
```bash
export LOG_LEVEL=debug
```

### Verbose Logging

Enable verbose logging in systemd:
```ini
[Service]
Environment=VERBOSE=true
```

### Configuration Validation

Validate configuration before deployment:
```bash
go run main.go --validate
```

## Best Practices

1. **Use Environment Variables**: Don't hardcode values in service definitions
2. **Secure Secrets**: Store secrets in `SECRETS_PATH` with proper permissions
3. **Health Checks**: Always define health checks for services
4. **Network Isolation**: Use appropriate networks for each service
5. **Label Consistency**: Use consistent label naming conventions
6. **Resource Limits**: Set memory and CPU limits for services
7. **Restart Policies**: Use `always` for critical services
8. **Dependencies**: Define `DependsOn` for service ordering

## Configuration Examples

See `services*.go` files for real-world configuration examples of all 57+ services.

