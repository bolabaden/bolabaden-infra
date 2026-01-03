# Constellation Agent - Zero-SPOF Gossip-Based HA Orchestration

A production-ready, zero single-point-of-failure orchestration system for Docker containers using gossip-based service discovery, Raft consensus, and dynamic Traefik configuration.

## 🚀 Quick Start

```bash
# Install agent
./scripts/install.sh

# Configure secrets
mkdir -p /opt/constellation/secrets
echo "your-cloudflare-api-token" > /opt/constellation/secrets/cf-api-token.txt
chmod 600 /opt/constellation/secrets/cf-api-token.txt

# Start agent
systemctl start constellation-agent
systemctl enable constellation-agent

# Verify installation
./scripts/verify.sh
```

See [QUICKSTART.md](docs/QUICKSTART.md) for detailed steps.

## 📋 Features

- **Zero SPOF**: No single points of failure, fully distributed
- **Gossip Protocol**: HashiCorp Memberlist for decentralized service discovery
- **Raft Consensus**: HashiCorp Raft for leader election and critical operations
- **Dynamic Traefik**: HTTP provider API for automatic routing configuration
- **Automatic DNS**: Cloudflare API integration for DNS management
- **Self-Healing**: Automatic service health monitoring and recovery
- **WARP Integration**: Anonymous egress network monitoring
- **Pure Go**: Zero YAML dependencies, all configuration in code

## 📁 Project Structure

```
infra/
├── cmd/
│   └── agent/           # Main agent binary
├── cluster/
│   ├── gossip/          # Gossip protocol implementation
│   └── raft/            # Raft consensus implementation
├── dns/                 # Cloudflare DNS management
├── monitoring/          # Health monitoring (WARP, services)
├── smartproxy/          # Smart failover proxy
├── stateful/            # Stateful service orchestration (MongoDB, Redis)
├── tailscale/           # Tailscale integration
├── traefik/             # Traefik HTTP provider
├── docs/                # Documentation
├── scripts/             # Installation and utility scripts
├── systemd/             # Systemd service files
├── services*.go         # Service definitions (57+ services)
└── main.go              # Service deployment tool
```

## 🏗️ Architecture

### Core Components

1. **Gossip Cluster** (`cluster/gossip/`)
   - Peer discovery via Tailscale
   - Service health broadcasting
   - Node state synchronization

2. **Raft Consensus** (`cluster/raft/`)
   - Leader election
   - Distributed lease management
   - Split-brain prevention

3. **Traefik HTTP Provider** (`traefik/`)
   - Dynamic HTTP/HTTPS routing
   - Dynamic TCP/UDP routing
   - Service discovery from gossip state

4. **DNS Controller** (`dns/`)
   - Cloudflare API integration
   - Automatic DNS record updates
   - Lease-based coordination

5. **Service Monitor** (`monitoring/`)
   - Docker container health checks
   - WARP gateway monitoring
   - Automatic health broadcasting

### Network Architecture

- **backend**: Node-local internal network
- **publicnet**: External-facing network for Traefik
- **warp-nat-net**: Anonymous egress network
- **Tailscale**: Secure mesh network for inter-node communication

## 📚 Documentation

- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Comprehensive deployment instructions
- **[Quickstart](docs/QUICKSTART.md)** - Rapid deployment checklist
- **[System Status](docs/SYSTEM_STATUS.md)** - Implementation status and architecture
- **[Plan Document](../../.cursor/plans/zero-spof_gossip_ha_e844e8e2.plan.md)** - Detailed design and implementation plan

## 🔧 Usage

### Deploy Services

```bash
cd infra
go run main.go
```

This deploys all services defined in `services*.go` files.

### Run Agent

```bash
# Start agent
systemctl start constellation-agent

# Check status
systemctl status constellation-agent

# View logs
journalctl -u constellation-agent -f
```

### Verify Installation

```bash
./scripts/verify.sh
```

## 🔐 Configuration

### Required Secrets

- `/opt/constellation/secrets/cf-api-token.txt` - Cloudflare API token

### Environment Variables

- `TS_HOSTNAME` - Tailscale hostname (defaults to system hostname)
- `DOMAIN` - Domain name for services (default: `bolabaden.org`)
- `PUBLIC_IP` - Public IP address (auto-detected if not set)
- `CONFIG_PATH` - Path for service volumes (default: `/opt/constellation/volumes`)
- `SECRETS_PATH` - Path for secrets (default: `/opt/constellation/secrets`)
- `DATA_DIR` - Path for Raft data (default: `/opt/constellation/data`)
- `CLOUDFLARE_ZONE_ID` - Cloudflare zone ID for DNS updates

### Service Configuration

Services are defined in Go code in `services*.go` files. Each service is a `Service` struct with:
- Container configuration (image, ports, volumes, etc.)
- Network assignments
- Health checks
- Traefik labels for routing
- Environment variables

## 🧪 Testing

### Verification Script

```bash
./scripts/verify.sh
```

### Chaos Testing

```bash
./scripts/chaos_test.sh
```

## 📊 Monitoring

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

View current cluster state via agent logs or gossip API.

### Raft Consensus

Raft state is stored in `/opt/constellation/data/raft/`:
- `logs/` - Raft log entries
- `stable/` - Stable store
- `snapshots/` - Raft snapshots

## 🛠️ Development

### Building

```bash
# Build agent
go build -o /usr/local/bin/constellation-agent ./cmd/agent

# Build service deployment tool
go build -o constellation-deploy ./main.go
```

### Adding Services

1. Define service in appropriate `services*.go` file
2. Add service to `defineServices()` in `services.go`
3. Deploy with `go run main.go`

### Code Style

- Follow Go standard formatting (`gofmt`)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

## 🐛 Troubleshooting

### Agent Won't Start

1. Check Docker: `systemctl status docker`
2. Check Tailscale: `tailscale status`
3. Check logs: `journalctl -u constellation-agent -n 100`
4. Verify secrets: `ls -la /opt/constellation/secrets/`

### Services Not Discovered

1. Verify services running: `docker ps`
2. Check agent logs for health monitoring
3. Verify gossip connectivity

### DNS Not Updating

1. Check DNS writer lease in logs
2. Verify Cloudflare API token
3. Check zone ID configuration
4. Check rate limits

### Traefik Not Getting Config

1. Test HTTP provider: `curl http://localhost:8081/api/http/routers`
2. Check Traefik static config includes HTTP provider
3. Verify Traefik can reach agent

See [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) for more troubleshooting tips.

## 🔒 Security

- Store secrets securely with proper permissions (600)
- Use Tailscale for secure inter-node communication
- Rotate Cloudflare API tokens regularly
- Restrict access to agent HTTP provider (port 8081)
- Run containers with least privilege
- Review systemd security settings

## 📈 Performance

### Tuning

- Gossip port: 7946 (adjustable)
- Raft port: 8300 (adjustable)
- HTTP provider port: 8081 (adjustable)
- Service health check: 10s (configurable in code)
- WARP health check: 30s (configurable in code)
- DNS reconciliation: 60s (configurable in code)

## 🤝 Contributing

1. Review the [plan document](../../.cursor/plans/zero-spof_gossip_ha_e844e8e2.plan.md)
2. Follow code style guidelines
3. Add tests where appropriate
4. Update documentation

## 📝 License

See project root LICENSE file.

## 🙏 Acknowledgments

- HashiCorp Memberlist for gossip protocol
- HashiCorp Raft for consensus
- Cloudflare for DNS API
- Traefik for reverse proxy
- Docker for containerization

## 📞 Support

For issues or questions:
1. Check logs: `journalctl -u constellation-agent -f`
2. Review documentation in `docs/`
3. Check code comments in source files
4. Review plan document

---

**Status: ✅ Production Ready**

See [SYSTEM_STATUS.md](docs/SYSTEM_STATUS.md) for complete implementation status.
