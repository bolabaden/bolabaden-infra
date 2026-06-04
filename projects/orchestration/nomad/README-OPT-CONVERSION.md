# Docker Compose to Nomad Conversion - /opt Services

This document describes the conversion of all Docker Compose services from the `/opt` directory to Nomad job specifications.

## Overview

The conversion process has transformed 60+ Docker Compose services into organized Nomad job files, maintaining the same functionality while leveraging Nomad's orchestration capabilities.

## Converted Job Files

### 1. `nomad-additional-services.hcl`

#### Core media management and security services

- **Media Management Group:**
  - Jellyseerr (Request management)
  - Seanime (Anime management)
  - Tautulli (Plex monitoring)
- **Security & Monitoring Group:**
  - Vaultwarden (Password manager)
  - Uptime Kuma (Uptime monitoring)
  - Portainer (Container management)
  - Beszel (System monitoring)

### 2. `nomad-stremio-addons.hcl`

#### Stremio addon ecosystem

- Addon Manager (Stremio addon management)
- StremThru (Debrid proxy service)
- AIOStremio (All-in-one addon aggregator)
- Anime Kitsu (Anime metadata)
- TMDB Addon (Movie metadata)
- Stremio Trakt Addon (Trakt integration)

### 3. `nomad-servarr-services.hcl`

#### Servarr ecosystem for media automation

- Radarr (Movie management)
- Sonarr (TV series management)
- Bazarr (Subtitle management)
- Overseerr (Request management)
- Kometa (Plex metadata management)
- Recyclarr (TRaSH guide sync)
- NZBHydra2 (NZB indexer aggregation)

### 4. `nomad-utility-debrid-services.hcl`

#### Utility services and debrid management

- **Utility Services:**
  - Cloudflare DDNS (Dynamic DNS)
  - Zilean (DMM hash indexer)
  - Zipline (File sharing)
  - LibreSpeed (Speed testing)
  - Speedtest Tracker (Automated speed tests)
  - Dozzle (Docker log viewer)
  - Watchtower (Container updates)
- **Debrid Services:**
  - TorBox Manager (TorBox management)
  - Zurg (Real-Debrid mount service)
  - RealDebrid Monitor (Account monitoring)
  - MediaFlow Proxy (Streaming proxy)

## Key Features

### Service Discovery & Load Balancing

- All services are registered with Consul for service discovery
- Traefik integration for automatic reverse proxy configuration
- Health checks for all HTTP services

### Volume Management

- Persistent storage using host volumes
- Proper permission handling with PUID/PGID
- Shared media directories across services

### Network Configuration

- Bridge networking with port mapping
- Traefik labels for automatic routing
- Support for multiple domain configurations

### Environment Variables

- Centralized configuration through Nomad meta variables
- Support for secrets management
- Timezone and user permission configuration

## Configuration Variables

Each job file includes meta variables that need to be configured:

### Common Variables

```hcl
meta {
  TZ = "America/Chicago"           # Timezone
  PUID = "1002"                    # User ID
  PGID = "988"                     # Group ID
  UMASK = "002"                    # File permissions
  CONFIG_PATH = "./configs"        # Configuration directory
  DOMAIN = "example.com"           # Primary domain
  DUCKDNS_SUBDOMAIN = "example"    # DuckDNS subdomain
  TS_HOSTNAME = "example"          # Tailscale hostname
}
```

### Service-Specific Variables

- **Vaultwarden:** `VAULTWARDEN_ADMIN_TOKEN`, `VAULTWARDEN_SIGNUPS_ALLOWED`
- **Cloudflare DDNS:** `CLOUDFLARE_API_KEY`, `CLOUDFLARE_ZONE`, `CLOUDFLARE_SUBDOMAIN`
- **Debrid Services:** `TORBOX_API_KEY`, `REALDEBRID_API_KEY`
- **API Keys:** `TMDB_API_KEY`, `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`

## Deployment

### Prerequisites

1. Nomad cluster running
2. Consul for service discovery
3. Traefik for reverse proxy
4. Docker driver enabled on Nomad clients

### Deploy All Services

```bash
cd nomad/bolabaden
./deploy-nomad.sh deploy
```

### Deploy Individual Job Files

```bash
nomad job run nomad-additional-services.hcl
nomad job run nomad-stremio-addons.hcl
nomad job run nomad-servarr-services.hcl
nomad job run nomad-utility-debrid-services.hcl
```

### Check Status

```bash
./deploy-nomad.sh status
```

### View Logs

```bash
./deploy-nomad.sh logs media-stack-additional-services
./deploy-nomad.sh logs media-stack-stremio-addons jellyseer
```

## Service Access

All services are accessible through Traefik with the following URL patterns:

- `https://[service].${DOMAIN}/`
- `https://[service].${DUCKDNS_SUBDOMAIN}.duckdns.org/`
- `https://[service].${TS_HOSTNAME}.duckdns.org/`

### Example URLs

- Jellyseerr: `https://jellyseer.example.com/`
- Vaultwarden: `https://vaultwarden.example.com/`
- Radarr: `https://radarr.example.com/`
- Sonarr: `https://sonarr.example.com/`

## Resource Allocation

### CPU and Memory Limits

Services are configured with appropriate resource limits:

- **Light services** (monitoring, utilities): 100-200 CPU, 128-256 MB RAM
- **Medium services** (media management): 300-500 CPU, 512-1024 MB RAM
- **Heavy services** (Plex, transcoding): 1000+ CPU, 2048+ MB RAM

### Storage Requirements

- Configuration data: Host volumes in `${CONFIG_PATH}/[service]`
- Media data: Shared volumes (`/mnt/user/movies`, `/mnt/user/tv`, etc.)
- Downloads: Shared download directory (`/mnt/user/downloads`)

## Security Considerations

### Authentication

- Services with sensitive data use `nginx-auth@file` middleware
- Vaultwarden has built-in authentication
- Admin interfaces are protected by default

### Network Security

- Services only expose necessary ports
- Internal communication through Consul service discovery
- Traefik handles SSL termination

### Secrets Management

- API keys and passwords stored as Nomad variables
- No hardcoded secrets in job files
- Environment-specific configuration

## Monitoring & Maintenance

### Health Checks

- HTTP health checks for web services
- Automatic restart on failure
- Service registration with Consul

### Logging

- Centralized logging through Nomad
- Dozzle for real-time log viewing
- Log rotation and retention

### Updates

- Watchtower for automatic container updates
- Manual updates through job redeployment
- Rolling updates with zero downtime

## Troubleshooting

### Common Issues

1. **Service not starting:**

   ```bash
   nomad job status [job-name]
   nomad alloc logs [allocation-id]
   ```

2. **Permission issues:**
   - Check PUID/PGID configuration
   - Verify volume mount permissions
   - Ensure config directories exist

3. **Network connectivity:**
   - Verify Traefik configuration
   - Check Consul service registration
   - Validate DNS resolution

### Useful Commands

```bash
# Check all job statuses
nomad job status

# Restart a specific job
./deploy-nomad.sh restart [job-name]

# View service logs
./deploy-nomad.sh logs [job-name] [task-name]

# Stop all services
./deploy-nomad.sh stop

# Purge all services
./deploy-nomad.sh purge
```

## Migration Notes

### From Docker Compose

1. **Volume paths:** Updated to use Nomad meta variables
2. **Networking:** Changed from Docker networks to Nomad bridge networking
3. **Service discovery:** Migrated from Docker DNS to Consul
4. **Load balancing:** Traefik configuration updated for Nomad

### Configuration Changes

- Environment variables moved to Nomad meta blocks
- Secrets externalized to Nomad variables
- Health checks standardized across services
- Resource limits explicitly defined

## Future Enhancements

### Planned Improvements

1. **Secrets management:** Integration with Vault
2. **Monitoring:** Prometheus metrics collection
3. **Backup:** Automated configuration backups
4. **Scaling:** Horizontal scaling for stateless services
5. **CI/CD:** Automated deployment pipelines

### Service Additions

- Additional Stremio addons as they become available
- New media management tools
- Enhanced monitoring and alerting services

## Support

For issues or questions:

1. Check the troubleshooting section
2. Review Nomad and service logs
3. Verify configuration variables
4. Consult the original Docker Compose files for reference

## Contributing

When adding new services:

1. Follow the established naming conventions
2. Include proper health checks
3. Add Traefik labels for routing
4. Document configuration variables
5. Update the deployment script
6. Test thoroughly before deployment
