# Changelog

All notable changes to the Constellation Agent project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-XX

### Added

#### Core Infrastructure
- **Gossip Protocol**: HashiCorp Memberlist integration for decentralized service discovery
- **Raft Consensus**: HashiCorp Raft integration for leader election and critical operations
- **Traefik HTTP Provider**: Dynamic configuration API with standard endpoints
- **Cloudflare DNS**: Automatic DNS record management via Cloudflare API
- **Service Monitoring**: Docker container health monitoring and broadcasting
- **WARP Monitoring**: Anonymous egress network gateway health monitoring
- **Smart Failover Proxy**: Circuit breaker pattern with status-aware failover

#### Service Migration
- Migrated 57+ services from Docker Compose to pure Go Service structs
- **Coolify-Proxy Stack**: 9 services (traefik, cloudflare-ddns, nginx-traefik-extensions, tinyauth, crowdsec, whoami, docker-gen-failover, logrotate-traefik, autokuma)
- **WARP Stack**: 4 services (warp-net-init, warp-nat-gateway, warp_router, ip-checker-warp)
- **Headscale Stack**: 2 services (headscale-server, headscale UI)
- **Authentik Stack**: 3 services (authentik, authentik-worker, authentik-postgresql)
- **Metrics Stack**: 9 services (victoriametrics, prometheus, grafana, node_exporter, cadvisor, loki, promtail, blackbox-exporter, init services)
- **Unsend Stack**: 2 services (unsend, unsend-postgres)
- **Firecrawl Stack**: 4 services (playwright-service, firecrawl, nuq-postgres, rabbitmq)
- **WordPress Stack**: 2 services (wordpress, mariadb)
- **LLM Stack**: 4 services (mcpo, litellm, litellm-postgres, gptr)
- **Stremio Stack**: 8 services (stremio, flaresolverr, jackett, prowlarr, aiostreams, stremthru, rclone, rclone-init)
- **Elfhosted Stack**: 10 services (filebrowser, gatus, homer, wizarr, zurg, rclonefm, rcloneui, traefik-forward-auth, riven, riven-frontend)

#### Network Management
- Automatic network creation (backend, publicnet, warp-nat-net)
- Network assignment based on service labels
- Tailscale integration for peer discovery
- WARP network health monitoring

#### Stateful Services
- MongoDB replica set orchestration
- Redis Sentinel orchestration
- Health monitoring and recovery

#### DNS Management
- Automatic public IP detection from external services
- Per-node DNS record reconciliation
- LB leader DNS updates (apex + wildcard)
- Lease-based coordination to prevent conflicts
- Rate limiting and drift correction

#### Traefik Integration
- Standard HTTP provider API endpoints
  - `/api/http/routers`
  - `/api/http/services`
  - `/api/http/middlewares`
  - `/api/tcp/routers`
  - `/api/tcp/services`
  - `/api/udp/routers`
  - `/api/udp/services`
- Legacy `/api/dynamic` endpoint for backward compatibility
- Dynamic HTTP/HTTPS router configuration
- Dynamic TCP/UDP router configuration
- Health-aware load balancing
- Automatic failover routing

#### Operational Tools
- Systemd service unit for agent management
- Installation script (`scripts/install.sh`)
- Verification script (`scripts/verify.sh`)
- Chaos testing framework (`scripts/chaos_test.sh`)

#### Documentation
- Comprehensive README with quick start guide
- Detailed deployment guide with troubleshooting
- Quickstart checklist for rapid deployment
- System status document with architecture overview
- Project summary with statistics and achievements

### Changed

- **Zero YAML Dependencies**: All configuration moved from YAML to pure Go structs
- **Imperative Infrastructure**: Replaced declarative Docker Compose with imperative Go code
- **Dynamic Configuration**: Traefik configuration now generated dynamically from gossip state
- **Service Discovery**: Moved from static configuration to gossip-based dynamic discovery

### Fixed

- Cloudflare API compatibility with v0.116.0
- Container health check implementation
- Network assignment logic
- Volume path resolution
- Docker API version compatibility (1.44+)
- Package structure for proper imports
- Duplicate method definitions

### Security

- Secure secret storage with proper file permissions
- Tailscale mesh network for inter-node communication
- Network isolation (backend, publicnet, warp-nat-net)
- Least privilege container execution
- Systemd security hardening

### Performance

- Config caching (5-second cache for Traefik config)
- Efficient gossip protocol with minimal overhead
- Rate limiting for Cloudflare API calls
- Optimized health check intervals (10-30 seconds)
- Thread-safe state management

## [Unreleased]

### Planned Enhancements
- Traefik port binding management via Docker API
- Redis password from config/secrets integration
- SmartProxy configuration from environment variables
- Enhanced chaos testing scenarios
- Metrics and observability improvements

---

## Version History

- **1.0.0** (2025-01-XX): Initial production release
  - Complete zero-SPOF orchestration system
  - 57+ services migrated
  - All core features implemented
  - Comprehensive documentation
  - Production-ready

---

## Notes

- All dates are approximate
- Version numbers follow semantic versioning
- Breaking changes will be clearly marked
- Security fixes will be prioritized

