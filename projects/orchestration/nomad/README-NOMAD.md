# Media Stack Nomad Deployment

This repository contains the converted Nomad job specifications for the comprehensive media stack originally defined in `docker-compose.yml`. The conversion preserves all functionality while adapting to Nomad's orchestration model.

## 📋 Overview

The original Docker Compose configuration has been converted into multiple Nomad job files for better organization and deployment management:

- **`nomad-media-stack.hcl`** - Core infrastructure (MongoDB, Redis, Qdrant, Traefik, system services)
- **`nomad-web-services.hcl`** - Web applications (SearxNG, Homepage, Speedtest, Dozzle, TinyAuth, Code Server, FlareSolverr)
- **`nomad-vpn-services.hcl`** - VPN and networking services (WARP, Tailscale, proxy services)
- **`nomad-ai-services.hcl`** - AI services (GPT Researcher, LobeChat)
- **`nomad-media-services.hcl`** - Media streaming services (Stremio, AIOStreams, Jackett, Prowlarr, Comet, MediaFusion)

## 🚀 Quick Start

### Prerequisites

1. **Nomad Cluster**: Ensure you have a running Nomad cluster
2. **Docker**: Docker must be available on Nomad client nodes
3. **Network Configuration**: Ensure proper networking is configured
4. **Environment Variables**: Set up required environment variables

### Deployment

1. **Clone and Navigate**:

   ```bash
   git clone <repository>
   cd my-media-stack
   ```

2. **Configure Variables**: Edit the `meta` blocks in each job file to match your environment:

   ```bash
   # Edit domain, paths, and API keys in each .hcl file
   vim nomad-media-stack.hcl
   vim nomad-web-services.hcl
   # ... etc
   ```

3. **Deploy All Services**:

   ```bash
   ./deploy-nomad.sh deploy
   ```

4. **Check Status**:

   ```bash
   ./deploy-nomad.sh status
   ```

## 🛠️ Configuration

### Required Variables

Each job file contains a `meta` block with configuration variables. Key variables to configure:

#### Domain Configuration

```hcl
DOMAIN = "your-domain.com"
DUCKDNS_SUBDOMAIN = "your-subdomain"
TS_HOSTNAME = "your-tailscale-hostname"
```

#### Paths

```hcl
CONFIG_PATH = "./configs"
CERTS_PATH = "./certs"
```

#### API Keys (set these in your environment)

```hcl
CLOUDFLARE_DNS_API_TOKEN = ""
LETS_ENCRYPT_EMAIL = ""
TMDB_API_KEY = ""
JACKETT_API_KEY = ""
PROWLARR_API_KEY = ""
# ... many more API keys for AI services
```

### Network Configuration

The original Docker Compose used a custom bridge network (`publicnet: 10.76.0.0/16`). In Nomad, this is handled through:

1. **Bridge Networking**: Each group uses `network { mode = "bridge" }`
2. **Service Discovery**: Nomad's built-in service discovery replaces static IP assignments
3. **Port Mapping**: Explicit port mappings replace Docker's port exposure

### Volume Mounts

All volume mounts from the original Docker Compose are preserved:

- Configuration files: `${CONFIG_PATH}/service-name/`
- Data persistence: Maintained through host path mounts
- Shared volumes: Converted to appropriate Nomad volume specifications

## 📁 Service Organization

### Core Infrastructure (`nomad-media-stack.hcl`)

- **MongoDB**: Document database
- **Redis**: Caching and session storage
- **Qdrant**: Vector database for AI services
- **Traefik**: Reverse proxy with automatic HTTPS
- **Watchtower**: Container update automation
- **DeUnhealth**: Health monitoring and restart automation
- **Error Pages**: Custom error page serving

### Web Services (`nomad-web-services.hcl`)

- **SearxNG**: Privacy-focused search engine
- **Homepage**: Dashboard and service overview
- **Speedtest Tracker**: Internet speed monitoring
- **Dozzle**: Real-time log viewer
- **TinyAuth**: Authentication service
- **Code Server**: Web-based IDE (dev and demo instances)
- **FlareSolverr**: Cloudflare bypass service
- **Nginx Auth**: Authentication middleware

### VPN Services (`nomad-vpn-services.hcl`)

- **WARP**: Cloudflare VPN service
- **Tailscale**: Mesh VPN integration
- **Proxy Services**: HTTP/SOCKS5 proxies

### AI Services (`nomad-ai-services.hcl`)

- **GPT Researcher**: AI research assistant with extensive API integrations
- **LobeChat**: AI chat interface

### Media Services (`nomad-media-services.hcl`)

- **Stremio**: Media streaming platform
- **AIOStreams**: Stremio addon aggregator
- **Jackett**: Torrent indexer proxy
- **Prowlarr**: Indexer manager
- **Comet**: Debrid service integration
- **MediaFusion**: Media content aggregation

## 🔧 Management Commands

The `deploy-nomad.sh` script provides comprehensive management:

```bash
# Validate all job files
./deploy-nomad.sh validate

# Deploy all services
./deploy-nomad.sh deploy

# Check service status
./deploy-nomad.sh status

# Stop all services
./deploy-nomad.sh stop

# Purge all services (stop and remove)
./deploy-nomad.sh purge

# Restart a specific service
./deploy-nomad.sh restart media-stack-core

# View logs
./deploy-nomad.sh logs media-stack-web-services
./deploy-nomad.sh logs media-stack-core mongodb

# Show help
./deploy-nomad.sh help
```

## 🌐 Networking and Access

### Service Discovery

Services communicate using Nomad's built-in service discovery:

- Services register with Consul (if available) or Nomad's native service discovery
- Internal communication uses service names (e.g., `mongodb`, `redis`)
- No need for static IP assignments

### External Access

All web services are accessible through Traefik reverse proxy:

- **Primary Domain**: `https://service.your-domain.com`
- **DuckDNS**: `https://service.your-subdomain.duckdns.org`
- **Tailscale**: `https://service.your-tailscale-hostname.duckdns.org`

### VPN Integration

The WARP and Tailscale services provide:

- **WARP**: Cloudflare VPN for bypassing geo-restrictions
- **Tailscale**: Secure mesh networking for remote access
- **Proxy Services**: HTTP/SOCKS5 proxies for applications

## 🔐 Security Considerations

### Authentication

Multiple authentication layers are implemented:

- **TinyAuth**: OAuth integration (Google, GitHub)
- **Nginx Auth**: API key and IP-based authentication
- **Traefik Middleware**: Request filtering and authentication

### Network Security

- **Isolated Networks**: Each service group runs in isolated bridge networks
- **Firewall Rules**: Only necessary ports are exposed
- **TLS Termination**: All external traffic uses HTTPS via Traefik

### Secrets Management

Sensitive data should be managed through:

- **Nomad Variables**: For job-specific configuration
- **Environment Variables**: For API keys and secrets
- **Vault Integration**: For enterprise secret management (if available)

## 📊 Monitoring and Logging

### Health Checks

All services include appropriate health checks:

- **HTTP Checks**: For web services
- **TCP Checks**: For databases and network services
- **Script Checks**: For complex health validation

### Logging

- **Dozzle**: Real-time log viewing for all containers
- **Nomad Logs**: Built-in log aggregation via `nomad alloc logs`
- **Centralized Logging**: Can be integrated with external log aggregation systems

### Monitoring

- **Homepage**: Service status dashboard
- **Speedtest Tracker**: Network performance monitoring
- **Traefik Dashboard**: Reverse proxy metrics and routing

## 🔄 Migration from Docker Compose

### Key Differences

1. **Service Discovery**: Nomad's service discovery replaces static IPs
2. **Networking**: Bridge networks instead of custom Docker networks
3. **Resource Management**: Explicit CPU/memory allocation
4. **Health Checks**: Nomad-native health checking
5. **Restart Policies**: Nomad's restart and reschedule policies

### Migration Steps

1. **Backup Data**: Ensure all persistent data is backed up
2. **Stop Docker Compose**: `docker-compose down`
3. **Configure Nomad Jobs**: Update variables in job files
4. **Deploy to Nomad**: Use the deployment script
5. **Verify Services**: Check all services are running correctly
6. **Update DNS**: Point domains to Nomad cluster if needed

## 🐛 Troubleshooting

### Common Issues

1. **Service Won't Start**:

   ```bash
   # Check job status
   nomad job status job-name
   
   # Check allocation logs
   nomad alloc logs allocation-id
   ```

2. **Network Connectivity**:

   ```bash
   # Verify service registration
   nomad service list
   
   # Check Consul services (if using Consul)
   consul catalog services
   ```

3. **Resource Constraints**:

   ```bash
   # Check node resources
   nomad node status
   
   # View resource allocation
   nomad job status job-name
   ```

### Log Analysis

```bash
# View logs for specific service
./deploy-nomad.sh logs media-stack-core mongodb

# Follow logs in real-time
nomad alloc logs -f allocation-id

# View logs from Dozzle web interface
https://dozzle.your-domain.com
```

### Performance Tuning

1. **Resource Allocation**: Adjust CPU/memory in job files
2. **Placement Constraints**: Add node constraints for specific services
3. **Scaling**: Increase `count` for services that can scale horizontally

## 📚 Additional Resources

- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Nomad Job Specification](https://www.nomadproject.io/docs/job-specification)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Driver Documentation](https://www.nomadproject.io/docs/drivers/docker)

## 🤝 Contributing

1. **Test Changes**: Always validate job files before committing
2. **Update Documentation**: Keep this README updated with changes
3. **Version Control**: Use semantic versioning for releases
4. **Security**: Never commit secrets or API keys

## 📄 License

This configuration is provided as-is. Please ensure you comply with the licenses of all included software components.

---

**Note**: This conversion maintains all functionality from the original Docker Compose setup while providing the benefits of Nomad orchestration including better resource management, service discovery, and cluster-wide deployment capabilities.
