# Docker Compose to Garden Migration

This project has been migrated from Docker Compose to Garden for better Kubernetes-native development and deployment.

## Project Structure

```bash
.
├── project.garden.yml                # Main Garden project configuration
├── coolify-proxy/                    # Reverse proxy and authentication services
│   ├── cloudflare-ddns.garden.yml
│   ├── nginx-traefik-extensions.garden.yml
│   ├── tinyauth.garden.yml
│   ├── crowdsec.garden.yml
│   ├── traefik.garden.yml
│   └── whoami.garden.yml
├── firecrawl/                        # Web scraping services
│   ├── playwright-service.garden.yml
│   ├── firecrawl-api.garden.yml
│   └── nuq-postgres.garden.yml
├── headscale/                        # Tailscale alternative
│   ├── headscale-server.garden.yml
│   └── headscale-ui.garden.yml
├── llm/                              # Large Language Model services
│   ├── open-webui.garden.yml
│   ├── mcpo.garden.yml
│   ├── litellm.garden.yml
│   ├── litellm-postgres.garden.yml
│   └── gptr.garden.yml
└── shared/                           # Shared services
    └── redis.garden.yml
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
   # ... other required variables
   ```

## Deployment

### 1. Deploy All Services
```bash
garden deploy
```

### 2. Deploy with Live Sync (Development)
```bash
garden deploy --sync
```

### 3. Deploy Specific Services
```bash
garden deploy traefik crowdsec
```

### 4. View Service Status
```bash
garden status
```

### 5. View Logs
```bash
garden logs traefik
garden logs --follow crowdsec
```

## Service Access

After deployment, services will be available at:

- **Traefik Dashboard**: https://traefik.${var.domain}
- **TinyAuth**: https://auth.${var.domain}
- **Open WebUI**: https://open-webui.${var.domain}
- **LiteLLM**: https://litellm.${var.domain}
- **Firecrawl API**: https://firecrawl-api.${var.domain}
- **Headscale UI**: https://headscale.${var.domain}
- **GPTR**: https://gptr.${var.domain}

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
- Defines global variables

### Service Configurations
Each service has its own `.garden.yml` file with:
- **Build actions**: Define how to build container images
- **Deploy actions**: Define how to deploy services
- **Dependencies**: Specify service startup order
- **Environment variables**: Service-specific configuration
- **Volumes**: Data persistence and configuration mounting
- **Ingresses**: External access configuration

## Troubleshooting

### Common Issues

1. **Service Dependencies**: Ensure all dependencies are properly declared
2. **Volume Mounts**: Check that source paths exist and are accessible
3. **Environment Variables**: Verify all required variables are set
4. **Resource Limits**: Adjust CPU/memory limits if services fail to start

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
```

## Migration Benefits

1. **Kubernetes Native**: Better integration with Kubernetes ecosystem
2. **Dependency Management**: Explicit service dependencies and startup order
3. **Live Sync**: Real-time code synchronization for development
4. **Caching**: Intelligent build and test caching
5. **Scalability**: Easy horizontal scaling of services
6. **Monitoring**: Better integration with Kubernetes monitoring tools

## Next Steps

1. Set up your environment variables
2. Deploy the services: `garden deploy`
3. Configure your domain and DNS
4. Set up SSL certificates through Traefik
5. Configure authentication through TinyAuth
6. Start developing with live sync: `garden deploy --sync`
