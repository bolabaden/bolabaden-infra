# Component Guide

This guide provides detailed documentation for each component of Constellation Agent. Each component is self-contained and can be understood independently.

## Gossip Cluster

**Location**: `cluster/gossip/`

The gossip cluster handles decentralized service discovery and state synchronization. It's built on HashiCorp Memberlist, which provides a robust gossip protocol implementation.

### How It Works

When a node starts, it:
1. Discovers other nodes via Tailscale
2. Joins the gossip cluster
3. Begins exchanging state with random peers
4. Merges incoming state with local state

State updates propagate through the cluster via gossip. Each node maintains a local view of the entire cluster state, which is kept in sync through periodic exchanges.

### Key Components

**GossipDelegate** (`delegate.go`)
- Implements `memberlist.Delegate` interface
- Handles state serialization and deserialization
- Manages broadcasts and message handling
- Creates minimal JSON when size limits are exceeded

**EventDelegate** (`delegate.go`)
- Implements `memberlist.EventDelegate` interface
- Handles node join/leave/update events
- Updates cluster state when nodes change

**GossipCluster** (`memberlist.go`)
- Main interface for gossip operations
- Manages memberlist instance
- Provides APIs for broadcasting health
- Handles node metadata updates

**ClusterState** (`state.go`)
- Thread-safe state storage
- Provides get/update/merge operations
- Tracks nodes, services, and WARP health
- Version tracking for change detection

### State Management

The cluster state includes:

- **Nodes**: Metadata about each node (IPs, priority, capabilities)
- **Service Health**: Health status for each service on each node
- **WARP Health**: WARP gateway health per node
- **Version**: Monotonic version number for change tracking

All state is thread-safe. Readers use read locks, writers use write locks. State is copied when returned to prevent external modification.

### Gossip Protocol

The gossip protocol works like this:

1. Each node periodically selects 3 random peers
2. Exchanges state updates with those peers
3. Merges incoming state using last-write-wins
4. Changed state propagates through the cluster

This provides eventual consistency. All nodes eventually see the same state, but there may be brief periods where views differ.

### Configuration

Gossip settings are tuned for Tailscale networks:

- Gossip interval: 200ms
- Probe interval: 1 second
- TCP timeout: 10 seconds
- Retransmit multiplier: 4

These can be adjusted in `memberlist.go` if needed.

## Raft Consensus

**Location**: `cluster/raft/`

Raft provides strong consistency for operations that can't tolerate split-brain scenarios. We use it for leader election and lease management.

### How It Works

When a node starts, it:
1. Joins the Raft cluster
2. Participates in leader election
3. Can acquire leases if elected leader
4. Replicates lease operations to followers

Only the leader can acquire leases. This prevents conflicts when multiple nodes try to perform the same operation simultaneously.

### Key Components

**ConsensusManager** (`consensus.go`)
- Manages Raft instance
- Handles leader election
- Provides lease management APIs
- Integrates with FSM for state changes

**FSM** (`fsm.go`)
- Implements `raft.FSM` interface
- Applies Raft commands to state
- Handles snapshots for persistence
- Manages lease state

**LeaseManager** (`leases.go`)
- Provides lease acquisition/renewal/release
- Uses Raft for strong consistency
- Handles lease expiration
- Provides callbacks for lease changes

### Leases

Two types of leases are managed:

**LB Leader Lease**
- Only one node can bind ports 80/443
- Prevents port conflicts
- Automatically transferred on leader change

**DNS Writer Lease**
- Only one node can update Cloudflare DNS
- Prevents race conditions
- Ensures atomic DNS updates

### Leader Election

Raft elects a leader based on:
- Term number (higher term wins)
- Node priority (lower priority wins)
- Log completeness

The leader sends heartbeats to followers. If followers don't receive heartbeats, they start a new election.

### Persistence

Raft state is persisted to disk:
- Logs: All Raft log entries
- Stable store: Current term and voted-for
- Snapshots: Periodic state snapshots

This allows the cluster to recover from failures and maintain consistency across restarts.

## Traefik HTTP Provider

**Location**: `traefik/`

The HTTP provider generates dynamic Traefik configuration from cluster state. Traefik polls this API for configuration updates.

### How It Works

1. Traefik polls the HTTP provider every 5 seconds
2. Provider queries cluster state for service health
3. Generates routers and services from healthy services
4. Returns JSON configuration to Traefik
5. Traefik updates its routing tables

Configuration is cached for 5 seconds to reduce CPU usage.

### Key Components

**HTTPProviderServer** (`http_provider.go`)
- HTTP server that Traefik polls
- Implements Traefik HTTP provider API
- Handles all endpoint requests
- Generates configuration from state

**Router Generation** (`routers.go`)
- Generates HTTP routers from service labels
- Creates direct node access routes
- Creates load-balanced routes
- Handles TLS configuration

**TCP/UDP Routing** (`tcp_udp.go`)
- Generates TCP routers and services
- Generates UDP routers and services
- Uses Tailscale IPs for backend addresses
- Supports L4 load balancing

### Routing Patterns

Two routing patterns are supported:

**Direct Node Access**
- Pattern: `<service>.<node>.bolabaden.org`
- Routes directly to service on specified node
- Used for debugging and direct access

**Load Balanced**
- Pattern: `<service>.bolabaden.org`
- Routes to healthy service across all nodes
- Automatically excludes unhealthy services
- Supports failover

### Configuration Generation

Configuration is generated by:
1. Querying cluster state for all services
2. Filtering to only healthy services
3. Extracting routing rules from labels
4. Building backend service lists
5. Adding health checks and load balancing

The result is valid Traefik configuration that routes traffic correctly.

## DNS Controller

**Location**: `dns/`

The DNS controller manages Cloudflare DNS records automatically based on cluster state.

### How It Works

1. Node holding DNS writer lease monitors cluster state
2. Detects changes to LB leader or node IPs
3. Updates Cloudflare DNS records via API
4. Handles rate limiting and retries
5. Performs drift correction periodically

Only the lease holder updates DNS, preventing conflicts.

### Key Components

**CloudflareClient** (`cloudflare.go`)
- Wraps Cloudflare API
- Handles authentication
- Manages DNS record operations
- Implements rate limiting

**DNSController** (`controller.go`)
- Coordinates DNS updates
- Monitors cluster state
- Updates records when needed
- Handles lease ownership

### DNS Records

Three types of records are managed:

**Apex Record**
- Name: `bolabaden.org`
- Points to: LB leader public IP
- Updated when: LB leader changes

**Wildcard Record**
- Name: `*.bolabaden.org`
- Points to: LB leader public IP
- Updated when: LB leader changes

**Per-Node Wildcard**
- Name: `*.<node>.bolabaden.org`
- Points to: Node's public IP
- Updated when: Node IP changes

### Rate Limiting

Cloudflare API has rate limits:
- 4 requests per second
- Burst limit: 10 requests

The controller batches updates and implements backoff to respect these limits.

### Drift Correction

Periodically, the controller checks if DNS records match cluster state. If they don't, it updates them. This handles cases where updates failed or were made manually.

## Service Monitor

**Location**: `monitoring/`

The service monitor tracks health of services running on the local node.

### How It Works

1. Queries Docker API for container status
2. Checks Docker healthcheck results
3. Discovers service endpoints and networks
4. Broadcasts health via gossip
5. Triggers restarts for unhealthy services

Monitoring runs continuously in the background.

### Health States

Services can be in three states:

**Healthy**
- Container is running
- Healthcheck is passing
- Included in routing

**Unhealthy**
- Container is running
- Healthcheck is failing
- Excluded from routing
- May be restarted automatically

**Stopped**
- Container is not running
- Excluded from routing
- Not restarted automatically

### Health Check Integration

The monitor respects Docker healthchecks:
- Uses healthcheck status if available
- Falls back to container state if no healthcheck
- Respects start period for slow services

### Automatic Restart

Services with `deunhealth.restart.on.unhealthy=true` label are automatically restarted when healthcheck fails. This provides self-healing capabilities.

## WARP Monitor

**Location**: `monitoring/warp.go`

The WARP monitor tracks health of the WARP gateway container.

### How It Works

1. Checks if `warp-nat-gateway` container is running
2. Tests egress connectivity through WARP
3. Verifies IP is a Cloudflare WARP IP
4. Broadcasts health via gossip

Monitoring runs every 30 seconds.

### Health Checks

The monitor performs:
- Container state check
- Egress connectivity test
- IP verification

If any check fails, WARP is marked unhealthy.

### Use Cases

WARP health is used to:
- Determine if anonymous egress is available
- Route services that need WARP to healthy nodes
- Alert when WARP gateway fails

## Smart Failover Proxy

**Location**: `smartproxy/`

The smart proxy provides advanced failover capabilities beyond what Traefik offers natively.

### How It Works

1. Receives requests from Traefik
2. Discovers healthy services from gossip state
3. Applies circuit breaker logic
4. Routes to healthy backend
5. Handles failures with status-aware failover

The proxy sits behind Traefik and provides additional intelligence.

### Key Components

**SmartFailoverProxy** (`proxy.go`)
- HTTP handler for requests
- Service discovery from gossip
- Failover logic
- Idempotency handling

**CircuitBreaker** (`circuit_breaker.go`)
- Prevents requests to failing backends
- Three states: Closed, Open, Half-Open
- Automatic recovery

**Health Endpoints** (`health.go`)
- Health check endpoint
- Metrics endpoint
- Status information

### Circuit Breaker

The circuit breaker prevents cascading failures:
- **Closed**: Normal operation, requests pass through
- **Open**: Backend is failing, requests fail fast
- **Half-Open**: Testing if backend recovered

This isolates failing services and prevents resource exhaustion.

### Status-Aware Failover

The proxy handles different failure types:
- **5xx errors**: Retry on another node
- **4xx errors**: Don't retry (client error)
- **Timeouts**: Retry on another node
- **Connection errors**: Retry on another node

This provides intelligent failover based on error type.

## Stateful Service Orchestration

**Location**: `stateful/`

Stateful services like databases need special handling. The orchestrator manages replica sets, primary detection, and failover.

### MongoDB Orchestration

**Location**: `stateful/mongodb.go`

Manages MongoDB replica sets:
- Initializes replica set on first node
- Detects primary node
- Configures replicas
- Handles primary failover

### Redis Orchestration

**Location**: `stateful/redis.go`

Manages Redis Sentinel:
- Configures sentinels
- Detects master node
- Configures slaves
- Handles master failover

### How It Works

1. First node initializes the cluster
2. Other nodes join as replicas
3. Orchestrator monitors primary/master
4. On failure, promotes a replica
5. Updates service endpoints

This provides high availability for stateful services.

## Tailscale Integration

**Location**: `tailscale/`

Tailscale provides secure mesh networking for inter-node communication.

### How It Works

1. Discovers Tailscale peers via CLI
2. Extracts Tailscale IPs
3. Uses IPs for gossip and Raft
4. Provides secure encrypted communication

### Key Components

**Discovery** (`discovery.go`)
- Discovers Tailscale peers
- Extracts node information
- Provides peer list for gossip

**Client** (`client.go`)
- Wraps Tailscale CLI
- Provides helper functions
- Handles errors gracefully

### Integration Points

Tailscale is used for:
- Gossip protocol communication
- Raft consensus communication
- Service discovery
- Secure inter-node traffic

All inter-node communication is encrypted via Tailscale.

## Service Deployment

**Location**: `main.go`, `services*.go`

Services are deployed via the Docker API. Each service is defined as a Go struct.

### Service Definition

Services are defined in `services*.go` files:
- `services.go`: Core services
- `services_coolify_proxy.go`: Reverse proxy stack
- `services_warp.go`: WARP network services
- `services_headscale.go`: Headscale services
- `services_authentik.go`: Authentik services
- `services_metrics.go`: Monitoring stack
- `services_unsend.go`: Unsend services
- `services_firecrawl.go`: Firecrawl services
- `services_wordpress.go`: WordPress services
- `services_llm.go`: LLM services
- `services_stremio.go`: Stremio services
- `services_elfhosted.go`: Elfhosted services

### Deployment Process

1. Ensure networks exist
2. Check if container exists
3. Remove existing container if needed
4. Build image if needed
5. Create container with config
6. Connect to networks
7. Start container

### Network Assignment

Networks are assigned based on:
- Service labels (automatic)
- Explicit network list (manual)
- Default network (backend)

This ensures services are on the right networks.

## Network Manager

**Location**: `network_manager.go`

Manages Docker network creation and existence.

### How It Works

1. Ensures default networks exist
2. Creates networks if missing
3. Configures IPAM
4. Sets bridge options

### Default Networks

Three networks are created by default:
- `backend`: Internal communication
- `publicnet`: External-facing services
- `warp-nat-net`: Anonymous egress

### Network Configuration

Networks are configured with:
- Subnet and gateway
- Bridge name
- Attachability
- Driver options

This provides proper network isolation.

## Error Handling

All components implement consistent error handling:

- **Log errors with context**: Include what operation failed and why
- **Retry transient failures**: Network errors, rate limits
- **Fail fast on permanent errors**: Invalid config, missing dependencies
- **Provide actionable messages**: Tell user how to fix the problem

This makes debugging easier and improves reliability.

## Testing

Each component can be tested independently:

- **Unit tests**: Test individual functions
- **Integration tests**: Test component interactions
- **End-to-end tests**: Test full system behavior

See the [Roadmap](ROADMAP.md) for planned test coverage improvements.

## Performance

Each component is optimized for performance:

- **Gossip**: Efficient serialization, minimal network usage
- **Raft**: Fast leader election, efficient log replication
- **HTTP Provider**: Config caching, fast generation
- **DNS Controller**: Rate limiting, batching
- **Service Monitor**: Parallel health checks

See the [Architecture Documentation](ARCHITECTURE.md) for performance characteristics.

