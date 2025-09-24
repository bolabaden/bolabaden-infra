# Docker Compose to Garden Migration

This project has been migrated from Docker Compose to Garden for better Kubernetes-native development and deployment. All Garden configurations are organized in the `garden.io/` directory.

## Project Structure

```bash
garden.io/
├── project.garden.yml                 # Main Garden project configuration
├── auth/                              # Authentication and identity services
│   ├── authentik-server.garden.yml
│   ├── authentik-worker.garden.yml
│   └── authentik-postgresql.garden.yml
├── coolify-proxy/                     # Reverse proxy and authentication services
│   ├── cloudflare-ddns.garden.yml
│   ├── nginx-traefik-extensions.garden.yml
│   ├── tinyauth.garden.yml
│   ├── crowdsec.garden.yml
│   ├── traefik.garden.yml
│   ├── whoami.garden.yml
│   ├── logrotate-traefik.garden.yml
│   └── autokuma.garden.yml
├── firecrawl/                         # Web scraping services
│   ├── playwright-service.garden.yml
│   ├── firecrawl-api.garden.yml
│   └── nuq-postgres.garden.yml
├── headscale/                         # Tailscale alternative
│   ├── headscale-server.garden.yml
│   └── headscale-ui.garden.yml
├── infrastructure/                    # Core infrastructure services
│   ├── code-server.garden.yml
│   ├── session-manager.garden.yml
│   ├── dozzle.garden.yml
│   ├── homepage.garden.yml
│   ├── watchtower.garden.yml
│   ├── dockerproxy-rw.garden.yml
│   └── portainer.garden.yml
├── llm/                               # Large Language Model services
│   ├── open-webui.garden.yml
│   ├── mcpo.garden.yml
│   ├── litellm.garden.yml
│   ├── litellm-postgres.garden.yml
│   └── gptr.garden.yml
├── metrics/                           # Monitoring and metrics stack
│   ├── victoriametrics-init.garden.yml
│   ├── victoriametrics.garden.yml
│   ├── prometheus-init.garden.yml
│   ├── prometheus.garden.yml
│   ├── grafana.garden.yml
│   ├── node-exporter.garden.yml
│   ├── cadvisor.garden.yml
│   └── blackbox-exporter.garden.yml
├── stremio/                          # Media streaming services
│   ├── stremio.garden.yml
│   ├── flaresolverr.garden.yml
│   ├── jackett.garden.yml
│   ├── prowlarr.garden.yml
│   ├── aiostreams.garden.yml
│   ├── comet.garden.yml
│   ├── mediafusion.garden.yml
│   ├── mediaflow-proxy.garden.yml
│   ├── stremthru.garden.yml
│   ├── rclone-init.garden.yml
│   └── rclone.garden.yml
├── warp/                             # VPN and routing services
│   ├── warp-nat-gateway.garden.yml
│   ├── warp-router.garden.yml
│   └── ip-checker-warp.garden.yml
├── wordpress/                        # WordPress CMS
│   ├── wordpress.garden.yml
│   └── mariadb.garden.yml
└── shared/                           # Shared services
    ├── redis.garden.yml
    ├── mongodb.garden.yml
    ├── searxng.garden.yml
    └── bolabaden-nextjs.garden.yml
```

## Key Migration Changes

### 1. Service Dependencies
- Services now explicitly declare dependencies using `dependencies` field
- Build actions are separate from Deploy actions for better caching
- Cross-service references use Garden's action reference system

### 2. Configuration Management
- Environment variables are centralized in `project.garden.yml`
- Volume mounts use `sourcePath` instead of Docker Compose volume syntax
- Config files are mounted as volumes with proper source paths

### 3. Networking
- Ingresses replace Docker Compose port mappings
- Services communicate through Kubernetes service discovery
- External access is handled through Traefik ingress controller

### 4. Health Checks
- Health checks are now Kubernetes-native (httpGet, exec)
- Proper dependency management ensures services start in correct order

## Prerequisites

1. **Garden CLI**: Install Garden CLI
   ```bash
   curl -sL https://get.garden.io/install.sh | bash
   ```

2. **Kubernetes Cluster**: Ensure you have a local Kubernetes cluster running
   - Docker Desktop with Kubernetes enabled, or
   - Minikube, or
   - Kind

3. **Environment Variables**: Set up your environment variables in a `.env` file or export them:
   ```bash
   export DOMAIN="your-domain.com"
   export CLOUDFLARE_API_TOKEN="your-token"
   export TINYAUTH_SECRET="your-secret"
   export GF_SECURITY_ADMIN_PASSWORD="your-password"
   export LITELLM_MASTER_KEY="your-key"
   export OPEN_WEBUI_SECRET_KEY="your-key"
   export MCPO_API_KEY="your-key"
   export FIRECRAWL_BULL_AUTH_KEY="your-key"
   export FIRECRAWL_TEST_API_KEY="your-key"
   # ... other required variables
   ```

## Deployment

### 1. Navigate to Garden Directory
```bash
cd garden.io
```

### 2. Deploy All Services
```bash
garden deploy
```

### 3. Deploy with Live Sync (Development)
```bash
garden deploy --sync
```

### 4. Deploy Specific Services
```bash
garden deploy traefik crowdsec victoriametrics grafana
```

### 5. View Service Status
```bash
garden status
```

### 6. View Logs
```bash
garden logs traefik
garden logs --follow crowdsec
```

## Service Access

After deployment, services will be available at:

### Infrastructure
- **Traefik Dashboard**: https://traefik.${DOMAIN}
- **TinyAuth**: https://auth.${DOMAIN}
- **Grafana**: https://grafana.${DOMAIN}
- **VictoriaMetrics**: https://victoriametrics.${DOMAIN}
- **Prometheus**: https://prometheus.${DOMAIN}
- **Homepage Dashboard**: https://homepage.${DOMAIN}
- **Portainer**: https://portainer.${DOMAIN}
- **Dozzle**: https://dozzle.${DOMAIN}
- **Code Server**: https://code-server.${DOMAIN}
- **HoloScript**: https://holoscript.${DOMAIN}
- **Rclone**: https://rclone.${DOMAIN}

### AI & LLM
- **Open WebUI**: https://open-webui.${DOMAIN}
- **LiteLLM**: https://litellm.${DOMAIN}
- **GPTR**: https://gptr.${DOMAIN}
- **MCPO**: https://mcpo.${DOMAIN}

### Media & Streaming  
- **Stremio**: https://stremio.${DOMAIN}
- **Jackett**: https://jackett.${DOMAIN}
- **Prowlarr**: https://prowlarr.${DOMAIN}
- **FlareSolverr**: https://flaresolverr.${DOMAIN}
- **AIOStreams**: https://aiostreams.${DOMAIN}
- **Comet**: https://comet.${DOMAIN}
- **MediaFusion**: https://mediafusion.${DOMAIN}
- **MediaFlow Proxy**: https://mediaflow-proxy.${DOMAIN}
- **StremThru**: https://stremthru.${DOMAIN}

### Search & Discovery
- **SearxNG**: https://searxng.${DOMAIN}

### Authentication & Identity
- **Authentik Server**: https://authentikserver.${DOMAIN}

### Content Management
- **WordPress**: https://wordpress.${DOMAIN}

### Networking & VPN
- **Headscale UI**: https://headscale.${DOMAIN}
- **Firecrawl API**: https://firecrawl-api.${DOMAIN}
- **WARP NAT Gateway**: (Internal routing service)

### Monitoring & Observability
- **cAdvisor**: https://cadvisor.${DOMAIN}
- **Blackbox Exporter**: https://blackbox.${DOMAIN}
- **Node Exporter**: (Internal metrics collector)

## Development Workflow

### Live Code Sync
Garden supports live code synchronization for development:

```bash
garden deploy --sync
```

This will:
- Watch for file changes in your source directories
- Automatically sync changes to running containers
- Restart services when necessary

### Building Images
```bash
garden build
```

### Running Tests
```bash
garden test
```

### Cleaning Up
```bash
garden delete
```

## Configuration Files

### Project Configuration (`project.garden.yml`)
- Defines the project name and environments
- Sets up the Kubernetes provider
- Defines global variables and environment variable mappings

### Service Configurations
Each service has its own `.garden.yml` file with:
- **Build actions**: Define how to build container images (for custom builds)
- **Deploy actions**: Define how to deploy services
- **Run actions**: Define initialization tasks
- **Dependencies**: Specify service startup order
- **Environment variables**: Service-specific configuration
- **Volumes**: Data persistence and configuration mounting
- **Ingresses**: External access configuration

## Environment Variables

The following environment variables need to be set:

### Required
```bash
# Core system
DOMAIN=your-domain.com
SUDO_PASSWORD=your-admin-password
MAIN_USERNAME=your-main-username

# DNS and SSL
CLOUDFLARE_API_TOKEN=your-cloudflare-token
ACME_RESOLVER_EMAIL=your-email@domain.com

# Authentication
TINYAUTH_SECRET=your-secret-key
AUTHENTIK_SECRET_KEY=your-authentik-secret

# Monitoring
GF_SECURITY_ADMIN_PASSWORD=your-grafana-password
REDIS_PASSWORD=your-redis-password

# AI/LLM
LITELLM_MASTER_KEY=your-litellm-key
OPEN_WEBUI_SECRET_KEY=your-openwebui-key
MCPO_API_KEY=your-mcpo-key

# Web scraping
FIRECRAWL_BULL_AUTH_KEY=your-firecrawl-key
FIRECRAWL_TEST_API_KEY=your-firecrawl-test-key
SEARXNG_SECRET=your-searxng-secret

# Media services
JACKETT_API_KEY=your-jackett-api-key
PROWLARR_API_KEY=your-prowlarr-api-key
TMDB_API_KEY=your-tmdb-api-key
TMDB_ACCESS_TOKEN=your-tmdb-access-token
AIOSTREAMS_SECRET_KEY=your-aiostreams-secret
MEDIAFLOW_PROXY_API_PASSWORD=your-mediaflow-password
```

### Optional - External Services
```bash
# Cloudflare (if using API key method)
CLOUDFLARE_EMAIL=your-email@domain.com
CLOUDFLARE_API_KEY=your-cloudflare-api-key
CLOUDFLARE_ZONE_ID=your-zone-id

# OAuth providers
TINYAUTH_GOOGLE_CLIENT_ID=your-google-client-id
TINYAUTH_GOOGLE_CLIENT_SECRET=your-google-client-secret
TINYAUTH_GITHUB_CLIENT_ID=your-github-client-id
TINYAUTH_GITHUB_CLIENT_SECRET=your-github-client-secret

# AI API keys
ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key
GROQ_API_KEY=your-groq-key
PERPLEXITY_API_KEY=your-perplexity-key
DEEPSEEK_API_KEY=your-deepseek-key
MISTRAL_API_KEY=your-mistral-key
GEMINI_API_KEY=your-gemini-key
OPENROUTER_API_KEY=your-openrouter-key

# Debrid services
REALDEBRID_API_KEY=your-realdebrid-key
REALDEBRID_TOKEN=your-realdebrid-token
ALLDEBRID_API_KEY=your-alldebrid-key
PREMIUMIZE_API_KEY=your-premiumize-key
DEBRIDLINK_API_KEY=your-debridlink-key
TORBOX_API_KEY=your-torbox-key
OFFCLOUD_API_KEY=your-offcloud-key
OFFCLOUD_EMAIL=your-offcloud-email
OFFCLOUD_PASSWORD=your-offcloud-password

# Additional integrations
GITHUB_TOKEN=your-github-token
TRAKT_CLIENT_ID=your-trakt-client-id
TRAKT_CLIENT_SECRET=your-trakt-client-secret
TELEGRAM_BOT_TOKEN=your-telegram-bot-token
TELEGRAM_CHAT_ID=your-telegram-chat-id
WARP_LICENSE_KEY=your-warp-license-key

# WordPress (if using)
WORDPRESS_DB_USER=your-wp-db-user
WORDPRESS_DB_PASSWORD=your-wp-db-password
WORDPRESS_DB_ROOT_PASSWORD=your-wp-root-password

# Development tools
CODESERVER_HASHED_PASSWORD=your-hashed-password
CODESERVER_SUDO_PASSWORD_HASH=your-sudo-hash
```

## Troubleshooting

### Common Issues

1. **Service Dependencies**: Ensure all dependencies are properly declared
2. **Volume Mounts**: Check that source paths exist and are accessible
3. **Environment Variables**: Verify all required variables are set
4. **Resource Limits**: Adjust CPU/memory limits if services fail to start
5. **Port Conflicts**: Ensure no port conflicts exist

### Debugging Commands

```bash
# Check service status
garden status

# View detailed logs
garden logs --follow <service-name>

# Check service health
garden get status <service-name>

# Debug configuration
garden debug

# Test connectivity
garden test
```

### Service Health Endpoints

Most services expose health endpoints:
- **/health** - Standard health check
- **/metrics** - Prometheus metrics (for monitoring services)
- **/-/healthy** - Prometheus-style health check
- **/api/health** - API health check

## Migration Benefits

1. **Kubernetes Native**: Better integration with Kubernetes ecosystem
2. **Dependency Management**: Explicit service dependencies and startup order
3. **Live Sync**: Real-time code synchronization for development
4. **Caching**: Intelligent build and test caching
5. **Scalability**: Easy horizontal scaling of services
6. **Monitoring**: Better integration with Kubernetes monitoring tools
7. **GitOps Ready**: Configuration as code with version control
8. **Multi-Environment**: Easy environment management and promotion

## Architecture Overview

### Infrastructure Layer
- **Traefik**: Reverse proxy and load balancer
- **Cloudflare DDNS**: Dynamic DNS updates
- **TinyAuth**: Authentication service
- **CrowdSec**: Security and intrusion prevention
- **WARP**: VPN gateway for secure routing

### Monitoring Stack
- **VictoriaMetrics**: Time series database
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics
- **Blackbox Exporter**: Endpoint monitoring

### AI/LLM Stack
- **Open WebUI**: Chat interface for LLMs
- **LiteLLM**: Multi-provider LLM gateway
- **MCPO**: MCP orchestrator
- **GPTR**: AI research assistant

### Media Stack
- **Stremio**: Media streaming platform
- **Jackett**: Torrent indexer aggregator
- **FlareSolverr**: Anti-bot proxy

### Shared Services
- **Redis**: Caching and message broker
- **PostgreSQL**: Databases for various services

## Deployment Profiles

Garden supports deployment profiles to deploy different service combinations:

### Core Infrastructure (Minimal)
```bash
garden deploy traefik tinyauth crowdsec redis
```

### Full Monitoring Stack
```bash
garden deploy victoriametrics prometheus grafana node-exporter cadvisor blackbox-exporter
```

### Complete Media Stack
```bash
garden deploy stremio flaresolverr jackett prowlarr aiostreams comet mediafusion stremthru
```

### AI/LLM Services
```bash
garden deploy open-webui litellm mcpo gptr
```

### Development Environment
```bash
garden deploy code-server session-manager dozzle portainer
```

## Service Dependencies

The migration maintains proper service dependencies:

1. **Database Services**: `redis`, `mongodb`, `authentik-postgresql`, `litellm-postgres`, `mariadb`
2. **Core Infrastructure**: `traefik`, `crowdsec`, `tinyauth`, `nginx-traefik-extensions`
3. **Monitoring Stack**: `victoriametrics` → `prometheus` → `grafana`
4. **Media Services**: `flaresolverr` → `jackett` → `prowlarr` → `comet`/`mediafusion`
5. **AI Stack**: `redis` → `litellm-postgres` → `litellm` → `open-webui`

## Next Steps

1. Set up your environment variables (see Environment Variables section)
2. Create volume directories: `mkdir -p volumes/{redis,mongodb,grafana,prometheus,victoriametrics}`
3. Deploy core services: `cd garden.io && garden deploy traefik tinyauth crowdsec redis`
4. Deploy monitoring: `garden deploy victoriametrics prometheus grafana`
5. Deploy additional services as needed
6. Configure your domain and DNS
7. Set up SSL certificates through Traefik  
8. Configure authentication through TinyAuth
9. Set up monitoring dashboards in Grafana
10. Start developing with live sync: `garden deploy --sync`

## Support

For issues and questions:
1. Check the Garden documentation: https://docs.garden.io/
2. Review service-specific logs: `garden logs <service-name>`
3. Verify environment variables and configuration
4. Check Kubernetes cluster status and resources
