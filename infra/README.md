# Constellation Agent

Constellation Agent is a distributed orchestration system that eliminates single points of failure while keeping things simple. Instead of relying on complex schedulers or centralized control planes, Constellation uses gossip protocols and consensus algorithms to coordinate services across multiple nodes.

Think of it as Kubernetes without the complexity, or Docker Swarm with better reliability. Every node can operate independently, and the system automatically handles failures, load balancing, and service discovery.

## What Makes It Different

Most orchestration systems have a central coordinator that other nodes depend on. If that coordinator fails, the whole system breaks. Constellation takes a different approach: every node is equal, and they coordinate through gossip. If one node fails, the others continue operating normally.

The system uses two coordination mechanisms:

- **Gossip Protocol**: For service discovery and health propagation. Fast, scalable, and eventually consistent.
- **Raft Consensus**: For operations that need strong consistency, like DNS updates or load balancer leadership. Prevents split-brain scenarios.

Everything is defined in Go code, not YAML. This gives you type safety, better tooling, and the ability to express complex logic that configuration files can't handle.

## Quick Start

Getting started is straightforward:

```bash
# Install the agent
./scripts/install.sh

# Set up your secrets
mkdir -p /opt/constellation/secrets
echo "your-cloudflare-api-token" > /opt/constellation/secrets/cf-api-token.txt
chmod 600 /opt/constellation/secrets/cf-api-token.txt

# Start the agent
systemctl start constellation-agent
systemctl enable constellation-agent

# Verify everything is working
./scripts/verify.sh
```

That's it. The agent will discover other nodes via Tailscale, start coordinating services, and begin managing DNS records automatically.

For more detailed instructions, see the [Quickstart Guide](docs/QUICKSTART.md).

## Features

**Zero Single Points of Failure**
Every component is distributed. There's no master node, no central registry, no single coordinator. If any node fails, the cluster continues operating.

**Gossip-Based Service Discovery**
Services advertise their health through gossip. No need to query a central registry. Information propagates naturally through the cluster.

**Automatic Load Balancing**
Traefik automatically routes traffic to healthy services across all nodes. If a service fails on one node, traffic routes to healthy instances on other nodes.

**Dynamic DNS Management**
DNS records are updated automatically based on cluster state. The system handles failover, load balancer changes, and node additions/removals.

**Self-Healing**
Services are monitored continuously. Unhealthy services are automatically restarted, and failed nodes are removed from routing until they recover.

**Multi-Network Support**
Services can be assigned to different networks based on their needs: internal communication, external-facing, or anonymous egress.

**Stateful Service Support**
Built-in orchestration for MongoDB replica sets and Redis Sentinel. The system handles initialization, primary detection, and failover automatically.

## How It Works

Constellation Agent runs on each node in your cluster. Each instance:

1. Discovers other nodes via Tailscale
2. Exchanges service health information through gossip
3. Participates in Raft consensus for critical decisions
4. Serves dynamic Traefik configuration via HTTP API
5. Manages DNS records through Cloudflare API
6. Monitors local services and broadcasts their health

There's no central coordinator. Each node makes decisions based on the gossip state it receives from peers.

When you deploy a service, it's automatically discovered by all nodes. Health checks run continuously, and failures are propagated through gossip. Traefik polls the HTTP provider for configuration, which is generated from the current gossip state. DNS records are updated by whichever node holds the DNS writer lease.

If a node fails, other nodes detect it through gossip and remove its services from routing. If the load balancer node fails, a new leader is elected via Raft, and DNS records are updated automatically.

## Architecture

The system is built from several core components:

- **Gossip Cluster**: Decentralized service discovery using HashiCorp Memberlist
- **Raft Consensus**: Leader election and lease management using HashiCorp Raft
- **Traefik HTTP Provider**: Dynamic configuration generation from cluster state
- **DNS Controller**: Automatic DNS record management via Cloudflare API
- **Service Monitor**: Health checking and status broadcasting
- **Smart Proxy**: Advanced failover with circuit breakers

For a detailed explanation of how these components work together, see the [Architecture Documentation](docs/ARCHITECTURE.md).

## Project Structure

```
infra/
├── cmd/
│   └── agent/              # Main agent binary
├── cluster/
│   ├── gossip/             # Gossip protocol implementation
│   └── raft/               # Raft consensus implementation
├── dns/                    # Cloudflare DNS management
├── monitoring/             # Health monitoring (WARP, services)
├── smartproxy/            # Smart failover proxy
├── stateful/               # Stateful service orchestration
├── tailscale/              # Tailscale integration
├── traefik/                # Traefik HTTP provider
├── docs/                   # Documentation
├── scripts/                # Installation and utility scripts
├── systemd/                # Systemd service files
├── services*.go            # Service definitions (57+ services)
└── main.go                 # Service deployment tool
```

## Documentation

We've put together comprehensive documentation to help you understand and use Constellation:

- **[Architecture Guide](docs/ARCHITECTURE.md)** - Deep dive into how the system works
- **[API Reference](docs/API.md)** - Complete API documentation
- **[Configuration Guide](docs/CONFIGURATION.md)** - All configuration options explained
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Step-by-step deployment instructions
- **[Quickstart Guide](docs/QUICKSTART.md)** - Get up and running quickly
- **[Roadmap](docs/ROADMAP.md)** - Planned features and improvements
- **[Component Guide](docs/COMPONENTS.md)** - Detailed component documentation

## Usage

### Deploying Services

Services are defined in Go code. To deploy all services:

```bash
cd infra
go run main.go
```

This reads service definitions from `services*.go` files and deploys them via the Docker API.

### Running the Agent

The agent runs as a systemd service:

```bash
# Start the agent
systemctl start constellation-agent

# Check status
systemctl status constellation-agent

# View logs
journalctl -u constellation-agent -f

# Stop the agent
systemctl stop constellation-agent
```

### Verifying Installation

Run the verification script to check that everything is working:

```bash
./scripts/verify.sh
```

This checks:
- Agent is running
- Gossip cluster is connected
- Raft consensus is working
- Traefik HTTP provider is responding
- DNS records are correct
- Services are healthy

## Configuration

Configuration is done through environment variables and service definitions. The most important settings:

- `TS_HOSTNAME`: Your Tailscale hostname
- `DOMAIN`: Base domain for services
- `CLOUDFLARE_ZONE_ID`: Cloudflare zone ID for DNS
- `CONFIG_PATH`: Path for service volumes
- `SECRETS_PATH`: Path for secrets

For a complete list of configuration options, see the [Configuration Guide](docs/CONFIGURATION.md).

## Services

Constellation includes definitions for 57+ services, including:

- **Reverse Proxy**: Traefik with dynamic configuration
- **Identity Provider**: Authentik for authentication
- **Monitoring**: Prometheus, Grafana, Loki, VictoriaMetrics
- **Media Services**: Stremio, Prowlarr, Jackett, Flaresolverr
- **AI Services**: LiteLLM, GPT-R, Firecrawl
- **Databases**: MongoDB (with replica sets), Redis (with Sentinel)
- **And many more...**

All services are defined in `services*.go` files. You can add your own by following the same pattern.

## Network Architecture

Constellation uses multiple Docker networks for isolation:

- **backend**: Internal communication between services
- **publicnet**: External-facing services behind Traefik
- **warp-nat-net**: Anonymous egress for services that need it
- **Tailscale**: Secure mesh network for inter-node communication

Services are automatically assigned to networks based on labels. You can also specify networks explicitly in service definitions.

## Security

Security is built into the design:

- **Tailscale Encryption**: All inter-node communication is encrypted via Tailscale
- **Secret Management**: Secrets are stored securely with proper permissions
- **Network Isolation**: Services are isolated by network
- **Least Privilege**: Containers run with minimal permissions
- **Health Checks**: Compromised services are automatically removed from routing

## Performance

The system is designed to be efficient:

- **Gossip Overhead**: ~15KB/s per node
- **Raft Overhead**: <1MB per day for logs
- **HTTP Provider**: <10ms config generation
- **DNS Updates**: Batched and rate limited

Tested with 100+ nodes and 1000+ services. Scales naturally as you add nodes.

## Troubleshooting

Common issues and solutions:

**Agent won't start**
- Check Docker: `systemctl status docker`
- Check Tailscale: `tailscale status`
- Check logs: `journalctl -u constellation-agent -n 100`

**Services not discovered**
- Verify services are running: `docker ps`
- Check agent logs for health monitoring
- Verify gossip connectivity

**DNS not updating**
- Check DNS writer lease in logs
- Verify Cloudflare API token
- Check rate limits

**Traefik not getting config**
- Test HTTP provider: `curl http://localhost:8081/api/http/routers`
- Check Traefik static config includes HTTP provider
- Verify Traefik can reach agent

For more troubleshooting tips, see the [Deployment Guide](docs/DEPLOYMENT_GUIDE.md).

## Development

### Building

```bash
# Build the agent
go build -o /usr/local/bin/constellation-agent ./cmd/agent

# Build the deployment tool
go build -o constellation-deploy ./main.go
```

### Adding Services

1. Define your service in an appropriate `services*.go` file
2. Add it to `defineServices()` in `services.go`
3. Deploy with `go run main.go`

### Code Style

- Follow Go standard formatting (`gofmt`)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

## Roadmap

We have big plans for Constellation. Check out the [Roadmap](docs/ROADMAP.md) to see what's coming next.

Some highlights:
- Web UI for cluster management
- Metrics collection and Prometheus integration
- Service autoscaling
- Blue-green and canary deployments
- Multi-region support

## Contributing

We welcome contributions! Here's how to get started:

1. Review the [Architecture Documentation](docs/ARCHITECTURE.md)
2. Check the [Roadmap](docs/ROADMAP.md) for areas that need work
3. Follow the code style guidelines
4. Add tests where appropriate
5. Update documentation

## License

See the project root LICENSE file for license information.

## Acknowledgments

Constellation builds on excellent open-source projects:

- **HashiCorp Memberlist** for gossip protocol
- **HashiCorp Raft** for consensus
- **Cloudflare** for DNS API
- **Traefik** for reverse proxy
- **Docker** for containerization
- **Tailscale** for secure networking

## Support

Having issues? Here's where to get help:

1. Check the logs: `journalctl -u constellation-agent -f`
2. Review the documentation in `docs/`
3. Check code comments in source files
4. Open an issue with details about your problem

---

**Status**: Production Ready ✅

Constellation is ready for production use. See the [Roadmap](docs/ROADMAP.md) for planned improvements and the [Architecture Documentation](docs/ARCHITECTURE.md) for implementation details.
