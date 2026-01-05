# Constellation Agent Architecture

Constellation Agent is a distributed orchestration system designed to eliminate single points of failure while maintaining simplicity. Instead of relying on centralized control planes or complex schedulers, Constellation uses gossip protocols and consensus algorithms to coordinate services across multiple nodes.

## Design Philosophy

The system follows a few core principles:

**Decentralization First**: Every node can operate independently. There's no master node that others depend on. If one node fails, the cluster continues operating.

**Gossip Over Centralization**: Rather than querying a central registry, nodes exchange information through gossip. This scales naturally and handles network partitions gracefully.

**Consensus Where It Matters**: For operations that require strong consistency (like DNS updates or load balancer leadership), we use Raft consensus. For everything else, eventual consistency via gossip is sufficient.

**Imperative Over Declarative**: All infrastructure is defined in Go code, not YAML. This gives us type safety, better tooling, and the ability to express complex logic that YAML can't handle.

## System Overview

Constellation Agent runs on each node in your cluster. Each agent instance:

1. Discovers other nodes via Tailscale
2. Exchanges service health information through gossip
3. Participates in Raft consensus for critical decisions
4. Serves dynamic Traefik configuration via HTTP API
5. Manages DNS records through Cloudflare API
6. Monitors local services and broadcasts their health

There's no central coordinator. Each node makes decisions based on the gossip state it receives from peers.

## Core Components

### Gossip Protocol (Memberlist)

The gossip layer handles service discovery and health propagation. When a service's health changes on one node, that information propagates to all other nodes through gossip.

**How it works:**
- Each node maintains a local view of cluster state
- Periodically, nodes exchange state updates with random peers
- Updates merge using last-write-wins semantics
- No central registry needed

**What gets gossiped:**
- Node metadata (IPs, capabilities, priority)
- Service health status (healthy/unhealthy, endpoints, networks)
- WARP gateway health

**Benefits:**
- Scales to hundreds of nodes
- Handles network partitions
- Self-healing (failed nodes are eventually detected)
- Low overhead (only changed state is transmitted)

### Raft Consensus

Raft provides strong consistency for operations that can't tolerate split-brain scenarios. We use it for:

- **Load Balancer Leadership**: Only one node should bind ports 80/443
- **DNS Writer Lease**: Only one node should update Cloudflare DNS records

**How it works:**
- Nodes form a Raft cluster
- Leader election happens automatically
- Only the leader can acquire leases
- Leases expire and renew automatically
- If the leader fails, a new leader is elected

**Why Raft instead of gossip for these?**
- DNS updates must be atomic (can't have two nodes updating simultaneously)
- Port binding conflicts would break routing
- Strong consistency prevents race conditions

### Traefik HTTP Provider

Traefik can discover services through Docker labels, but that only works for services on the same node. The HTTP provider lets us generate dynamic configuration based on gossip state, enabling cross-node routing.

**How it works:**
- Agent runs an HTTP server on port 8081
- Traefik polls this server for configuration
- Agent generates config from gossip state
- Routes point to healthy services across all nodes

**Endpoints:**
- `/api/http/routers` - HTTP/HTTPS routing rules
- `/api/http/services` - Backend service definitions
- `/api/http/middlewares` - Middleware configurations
- `/api/tcp/routers` - TCP routing rules
- `/api/tcp/services` - TCP backend services
- `/api/udp/routers` - UDP routing rules
- `/api/udp/services` - UDP backend services

**Routing Patterns:**
- `<service>.bolabaden.org` → Load balanced across all healthy nodes
- `<service>.<node>.bolabaden.org` → Direct to specific node

### DNS Management

DNS records are managed automatically based on cluster state. The node holding the DNS writer lease updates Cloudflare records.

**Records managed:**
- `bolabaden.org` (apex) → Points to LB leader
- `*.bolabaden.org` (wildcard) → Points to LB leader
- `*.<node>.bolabaden.org` (per-node wildcard) → Points to that node's public IP

**Coordination:**
- Only the lease holder updates DNS
- Prevents conflicts and race conditions
- Automatic failover if lease holder fails

### Service Health Monitoring

Each agent monitors services running on its local node:

- Queries Docker API for container status
- Checks Docker healthcheck results
- Discovers service endpoints and networks
- Broadcasts health via gossip

**Health States:**
- **Healthy**: Container running and healthcheck passing
- **Unhealthy**: Container running but healthcheck failing
- **Stopped**: Container not running

**Integration:**
- Services with `deunhealth.restart.on.unhealthy=true` label are automatically restarted
- Traefik only routes to healthy services
- Failed services are removed from routing until recovered

### WARP Network Monitoring

WARP provides anonymous egress for services that need it. The agent monitors the WARP gateway health and broadcasts it to the cluster.

**Monitoring:**
- Checks if `warp-nat-gateway` container is running
- Tests egress connectivity through WARP
- Verifies IP is a Cloudflare WARP IP

**Use cases:**
- Services that need anonymous outbound connections
- Bypassing geo-restrictions
- Privacy-sensitive operations

## Network Architecture

Constellation uses multiple Docker networks for isolation and security:

### Backend Network

**Purpose**: Node-local internal communication

**Characteristics:**
- Default network for all services
- Services can communicate via service name
- Not exposed to external traffic
- Subnet: `10.0.7.0/24` (configurable)

**Use cases:**
- Database connections
- Internal API calls
- Service-to-service communication

### Publicnet Network

**Purpose**: External-facing services behind Traefik

**Characteristics:**
- Services with `traefik.enable=true` label join this network
- Traefik can route to services on this network
- Services are not directly exposed (Traefik is the entry point)
- Subnet: `10.76.0.0/16` (configurable)

**Use cases:**
- Web applications
- APIs
- Services that need HTTPS termination

### WARP Network (warp-nat-net)

**Purpose**: Anonymous egress for services

**Characteristics:**
- Services with `network.warp.enabled=true` label join this network
- Routes traffic through Cloudflare WARP
- Provides anonymous outbound connections
- Subnet: `10.0.2.0/24` (configurable)

**Use cases:**
- Web scraping
- API calls that need different IP
- Privacy-sensitive outbound traffic

### Tailscale Mesh

**Purpose**: Secure inter-node communication

**Characteristics:**
- Encrypted mesh VPN
- Each node gets a Tailscale IP
- Used for gossip and Raft communication
- Not a Docker network (host-level)

**Use cases:**
- Gossip protocol traffic
- Raft consensus communication
- Cross-node service discovery

## Data Flow

### Service Deployment Flow

1. **Deploy**: `go run main.go` deploys services via Docker API
2. **Network Assignment**: Services assigned to networks based on labels
3. **Health Monitoring**: Agent starts monitoring service health
4. **Gossip Broadcast**: Health status broadcast to cluster
5. **Traefik Update**: Traefik polls HTTP provider, gets updated config
6. **DNS Update**: DNS records updated if this node is LB leader

### Request Flow

1. **DNS Lookup**: Client resolves `service.bolabaden.org`
2. **DNS Response**: Returns IP of LB leader node
3. **Request**: Client sends request to LB leader
4. **Traefik**: Traefik receives request, checks HTTP provider config
5. **Routing**: Traefik routes to healthy service (local or remote)
6. **Response**: Service responds, Traefik proxies back to client

### Failover Flow

1. **Service Fails**: Healthcheck fails on node A
2. **Health Update**: Agent on node A broadcasts unhealthy status
3. **Gossip Propagation**: Other nodes receive update via gossip
4. **Traefik Update**: Traefik HTTP provider removes failed service
5. **Traffic Redirect**: New requests route to healthy service on node B
6. **Recovery**: If service recovers, it's automatically added back

### Leader Election Flow

1. **Node Starts**: Agent starts, joins Raft cluster
2. **Election**: Raft elects leader based on priority and term
3. **Lease Acquisition**: Leader acquires LB leader and DNS writer leases
4. **Port Binding**: Leader binds ports 80/443 for Traefik
5. **DNS Update**: Leader updates Cloudflare DNS records
6. **Failover**: If leader fails, new leader elected, leases transferred

## State Management

### Cluster State

The `ClusterState` struct holds the complete view of the cluster:

```go
type ClusterState struct {
    Nodes         map[string]*NodeMetadata
    ServiceHealth map[string]*ServiceHealth
    WARPHealth    map[string]*WARPHealth
    Version       uint64
}
```

**Thread Safety:**
- All access protected by `sync.RWMutex`
- Readers use `RLock`, writers use `Lock`
- State is copied when returned to prevent external modification

**Merging:**
- Incoming state merged using last-write-wins
- Timestamps determine which data is newer
- Version number increments on each change

### Node Metadata

Each node's metadata includes:
- Name (hostname)
- Public IP (for DNS records)
- Tailscale IP (for inter-node communication)
- Priority (for leader election)
- Capabilities (what this node can do)
- Last seen timestamp
- Cordoned flag (prevent new traffic)

### Service Health

Service health entries track:
- Service name
- Node name
- Health status (healthy/unhealthy)
- Endpoints (protocol → URL mapping)
- Networks (which Docker networks service is on)
- Last checked timestamp

## Error Handling

### Gossip Failures

If gossip fails:
- Node continues operating with last known state
- Attempts to rejoin cluster periodically
- Logs warnings but doesn't crash

### Raft Failures

If Raft fails:
- Node can't acquire leases
- Can't perform DNS updates
- Continues serving traffic if already leader
- Attempts to rejoin Raft cluster

### DNS Update Failures

If DNS update fails:
- Error logged
- Retry with exponential backoff
- Rate limiting prevents API abuse
- Drift correction ensures eventual consistency

### Traefik Provider Failures

If HTTP provider fails:
- Traefik continues using last known config
- Agent logs errors
- Service discovery may be stale until recovery

## Performance Characteristics

### Gossip Overhead

- Each node gossips with 3 random peers every 200ms
- Only changed state is transmitted
- Typical message size: <1KB
- Network overhead: ~15KB/s per node

### Raft Overhead

- Leader sends heartbeat every 50ms
- Log entries only on lease changes
- Typical log size: <100 bytes per entry
- Disk overhead: <1MB per day

### HTTP Provider Overhead

- Traefik polls every 5 seconds
- Config generation: <10ms
- Response size: <50KB for 100 services
- CPU overhead: negligible

### DNS Update Overhead

- Updates batched and rate limited
- Typical update: 1 API call per record
- Cloudflare rate limit: 4 req/s
- Drift correction: once per minute

## Scalability

### Node Limits

- Gossip: Tested up to 100 nodes
- Raft: Recommended <10 nodes (consensus overhead)
- Services: No hard limit (tested with 100+ services)

### Network Limits

- Tailscale: Supports 100+ nodes
- Docker networks: No practical limit
- Traefik: Handles 1000+ routes efficiently

### State Size

- Cluster state: <1MB for 100 nodes, 1000 services
- Raft logs: <10MB for typical operation
- Gossip messages: <1KB per message

## Security Considerations

### Inter-Node Communication

- Tailscale provides encryption
- No unencrypted traffic between nodes
- Mesh VPN prevents MITM attacks

### API Security

- HTTP provider should be firewalled (only Traefik should access)
- Cloudflare API token stored securely
- Secrets mounted read-only in containers

### Container Security

- Services run with least privilege
- Network isolation prevents lateral movement
- Health checks prevent routing to compromised services

## Failure Modes

### Single Node Failure

- Other nodes detect via gossip
- Services on failed node removed from routing
- Traffic routes to healthy nodes
- DNS updated if failed node was LB leader

### Network Partition

- Gossip continues within partition
- Raft prevents split-brain (only one partition has leader)
- DNS updates only from leader partition
- Automatic reconciliation when partition heals

### Complete Cluster Failure

- Services continue running (Docker handles restarts)
- No new routing updates until cluster recovers
- DNS records remain pointing to last known LB leader
- Manual intervention may be needed

## Monitoring and Observability

### Logs

- Agent logs to systemd journal
- Structured logging with context
- Log levels: INFO, WARN, ERROR
- Rotation handled by systemd

### Metrics

- Service health status
- Gossip message counts
- Raft leader status
- DNS update success/failure

### Health Endpoints

- HTTP provider: `/health`
- Agent: Check systemd status
- Services: Docker healthchecks

## Future Enhancements

See [ROADMAP.md](ROADMAP.md) for planned improvements and feature additions.

