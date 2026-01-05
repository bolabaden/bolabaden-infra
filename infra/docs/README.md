# Constellation Agent Documentation

Welcome to the Constellation Agent documentation. This guide will help you understand, deploy, and use Constellation Agent effectively.

## Getting Started

New to Constellation? Start here:

1. **[Quickstart Guide](QUICKSTART.md)** - Get up and running in minutes
2. **[Architecture Overview](ARCHITECTURE.md)** - Understand how it works
3. **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Deploy to your infrastructure

## Core Documentation

### Architecture and Design

- **[Architecture Guide](ARCHITECTURE.md)** - Deep dive into system design, components, and data flow
- **[Component Guide](COMPONENTS.md)** - Detailed documentation for each component
- **[API Reference](API.md)** - Complete API documentation

### Configuration and Usage

- **[Configuration Guide](CONFIGURATION.md)** - All configuration options explained
- **[Examples](EXAMPLES.md)** - Practical examples and use cases
- **[Roadmap](ROADMAP.md)** - Planned features and improvements

### Operations

- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Step-by-step deployment instructions
- **[Verification Guide](VERIFICATION.md)** - How to verify your installation
- **[Troubleshooting](DEPLOYMENT_GUIDE.md#troubleshooting)** - Common issues and solutions

## Documentation Structure

### For Users

If you're deploying or using Constellation:

1. Read the [Quickstart Guide](QUICKSTART.md) to get started
2. Review the [Configuration Guide](CONFIGURATION.md) for your setup
3. Check [Examples](EXAMPLES.md) for common patterns
4. Refer to [Troubleshooting](DEPLOYMENT_GUIDE.md#troubleshooting) if you have issues

### For Developers

If you're contributing or extending Constellation:

1. Read the [Architecture Guide](ARCHITECTURE.md) to understand the design
2. Review the [Component Guide](COMPONENTS.md) for implementation details
3. Check the [API Reference](API.md) for integration points
4. See the [Roadmap](ROADMAP.md) for areas that need work

### For Operators

If you're running Constellation in production:

1. Follow the [Deployment Guide](DEPLOYMENT_GUIDE.md) for setup
2. Review the [Configuration Guide](CONFIGURATION.md) for tuning
3. Use the [Verification Guide](VERIFICATION.md) to validate
4. Monitor using the [Architecture Guide](ARCHITECTURE.md#monitoring-and-observability)

## Quick Reference

### Common Tasks

**Deploy Services**
```bash
cd infra
go run main.go
```

**Start Agent**
```bash
systemctl start constellation-agent
```

**Check Status**
```bash
systemctl status constellation-agent
```

**View Logs**
```bash
journalctl -u constellation-agent -f
```

**Verify Installation**
```bash
./scripts/verify.sh
```

### Key Concepts

- **Gossip Protocol**: Decentralized service discovery
- **Raft Consensus**: Strong consistency for critical operations
- **HTTP Provider**: Dynamic Traefik configuration
- **DNS Controller**: Automatic DNS management
- **Service Monitor**: Health checking and broadcasting

### Important Files

- `services*.go`: Service definitions
- `cmd/agent/main.go`: Agent entry point
- `cluster/gossip/`: Gossip protocol
- `cluster/raft/`: Raft consensus
- `traefik/`: Traefik HTTP provider
- `dns/`: DNS management

## Documentation Updates

Documentation is updated as features are added and improved. Check the [Roadmap](ROADMAP.md) to see what's coming next.

If you find errors or have suggestions, please open an issue or submit a pull request.

## Additional Resources

- **Main README**: [../README.md](../README.md) - Project overview
- **Source Code**: [../](../) - Browse the codebase
- **Scripts**: [../scripts/](../scripts/) - Installation and utility scripts

---

*Last updated: 2024*

