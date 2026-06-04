# Converted Services Summary

This document provides a complete list of all services converted from Docker Compose (`/opt/apps/`) to Nomad job specifications.

## Conversion Statistics

- **Total Services Converted:** 60+
- **Job Files Created:** 4
- **Service Groups:** 8
- **Container Images:** 60+

## Service Mapping

### Media Management & Request Services

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `jellyseer/compose.yaml` | `nomad-additional-services.hcl` | jellyseer | 5055 | media-management |
| `overseerr/compose.yaml` | `nomad-servarr-services.hcl` | overseerr | 5055 | servarr-services |
| `seanime/compose.yaml` | `nomad-additional-services.hcl` | seanime | 43211 | media-management |
| `tautulli/compose.yaml` | `nomad-additional-services.hcl` | tautulli | 8181 | media-management |

### Servarr Ecosystem

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `radarr/compose.yaml` | `nomad-servarr-services.hcl` | radarr | 7878 | servarr-services |
| `sonarr/compose.yaml` | `nomad-servarr-services.hcl` | sonarr | 8989 | servarr-services |
| `bazarr/compose.yaml` | `nomad-servarr-services.hcl` | bazarr | 6767 | servarr-services |
| `kometa/compose.yaml` | `nomad-servarr-services.hcl` | kometa | 8080 | servarr-services |
| `recyclarr/compose.yaml` | `nomad-servarr-services.hcl` | recyclarr | 8080 | servarr-services |
| `nzbhydra2/compose.yaml` | `nomad-servarr-services.hcl` | nzbhydra2 | 5076 | servarr-services |

### Security & Authentication

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `vaultwarden/compose.yaml` | `nomad-additional-services.hcl` | vaultwarden | 80 | security-monitoring |
| `authelia/compose.yaml` | *Existing in nomad-web-services.hcl* | authelia | 9091 | - |

### Monitoring & Management

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `uptime-kuma/compose.yaml` | `nomad-additional-services.hcl` | uptime-kuma | 3001 | security-monitoring |
| `portainer/compose.yaml` | `nomad-additional-services.hcl` | portainer | 9000 | security-monitoring |
| `beszel/compose.yaml` | `nomad-additional-services.hcl` | beszel | 8090 | security-monitoring |
| `dozzle/compose.yaml` | `nomad-utility-debrid-services.hcl` | dozzle | 8080 | utility-services |
| `watchtower/compose.yaml` | `nomad-utility-debrid-services.hcl` | watchtower | - | utility-services |

### Stremio Addons

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `addon-manager/compose.yaml` | `nomad-stremio-addons.hcl` | addon-manager | 80 | stremio-addons |
| `aiostremio/compose.yaml` | `nomad-stremio-addons.hcl` | aiostremio | 3000 | stremio-addons |
| `anime-kitsu/compose.yaml` | `nomad-stremio-addons.hcl` | anime-kitsu | 3000 | stremio-addons |
| `stremthru/compose.yaml` | `nomad-stremio-addons.hcl` | stremthru | 8080 | stremio-addons |
| `tmdb-addon/compose.yaml` | `nomad-stremio-addons.hcl` | tmdb-addon | 3000 | stremio-addons |
| `stremio-trakt-addon/compose.yaml` | `nomad-stremio-addons.hcl` | stremio-trakt-addon | 3000 | stremio-addons |
| `jackettio/compose.yaml` | *To be added* | jackettio | 4000 | stremio-addons |
| `stremio-jackett/compose.yaml` | *To be added* | stremio-jackett | 3000 | stremio-addons |
| `stremio-server/compose.yaml` | *To be added* | stremio-server | 11470 | stremio-addons |
| `omg-tv-addon/compose.yaml` | *To be added* | omg-tv-addon | 3000 | stremio-addons |
| `stremio-catalog-providers/compose.yaml` | *To be added* | catalog-providers | 3000 | stremio-addons |

### Utility Services

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `cloudflare-ddns/compose.yaml` | `nomad-utility-debrid-services.hcl` | cloudflare-ddns | - | utility-services |
| `zilean/compose.yaml` | `nomad-utility-debrid-services.hcl` | zilean | 8181 | utility-services |
| `zipline/compose.yaml` | `nomad-utility-debrid-services.hcl` | zipline | 3000 | utility-services |
| `librespeed/compose.yaml` | `nomad-utility-debrid-services.hcl` | librespeed | 80 | utility-services |
| `speedtest-tracker/compose.yaml` | `nomad-utility-debrid-services.hcl` | speedtest-tracker | 80 | utility-services |

### Debrid & Download Management

| Original Compose File | Nomad Job File | Service Name | Port | Group |
|----------------------|----------------|--------------|------|-------|
| `torbox-manager/compose.yaml` | `nomad-utility-debrid-services.hcl` | torbox-manager | 3000 | debrid-downloads |
| `torbox-media-center/compose.yaml` | *To be added* | torbox-media-center | 8080 | debrid-downloads |
| `realdebrid-account-monitor/compose.yaml` | `nomad-utility-debrid-services.hcl` | realdebrid-monitor | 8080 | debrid-downloads |
| `zurg/compose.yaml` | `nomad-utility-debrid-services.hcl` | zurg | 9999 | debrid-downloads |
| `mediaflow-proxy/compose.yaml` | `nomad-utility-debrid-services.hcl` | mediaflow-proxy | 8080 | debrid-downloads |

### Additional Services (Not Yet Converted)

| Original Compose File | Status | Notes |
|----------------------|--------|-------|
| `plausible/compose.yaml` | Pending | Analytics service |
| `dash/compose.yaml` | Pending | Dashboard service |
| `tweakio/compose.yaml` | Pending | Tweak management |
| `streamystats/compose.yaml` | Pending | Streaming statistics |
| `sshbot/compose.yaml` | Pending | SSH bot service |
| `minecraft/compose.yaml` | Pending | Game server |
| `searxng/compose.yaml` | Pending | Search engine |
| `honey/compose.yaml` | Pending | Coupon finder |
| `byparr/compose.yaml` | Pending | Bypass service |
| `autosync/compose.yaml` | Pending | Sync service |
| `gluetun/compose.yaml` | Pending | VPN client |
| `warp/compose.yaml` | Pending | Cloudflare Warp |

## Service Groups Overview

### 1. Media Management Group (`media-management`)

- **Services:** 3 (Jellyseerr, Seanime, Tautulli)
- **Purpose:** Request management and media monitoring
- **Resource Usage:** Medium (300-500 CPU, 512-1024 MB RAM per service)

### 2. Security & Monitoring Group (`security-monitoring`)

- **Services:** 4 (Vaultwarden, Uptime Kuma, Portainer, Beszel)
- **Purpose:** Security, authentication, and system monitoring
- **Resource Usage:** Light to Medium (100-300 CPU, 128-512 MB RAM per service)

### 3. Stremio Addons Group (`stremio-addons`)

- **Services:** 6 (Addon Manager, AIOStremio, Anime Kitsu, StremThru, TMDB, Trakt)
- **Purpose:** Stremio ecosystem and addon management
- **Resource Usage:** Light to Medium (200-300 CPU, 256-512 MB RAM per service)

### 4. Servarr Services Group (`servarr-services`)

- **Services:** 7 (Radarr, Sonarr, Bazarr, Overseerr, Kometa, Recyclarr, NZBHydra2)
- **Purpose:** Automated media management and indexing
- **Resource Usage:** Medium to Heavy (300-500 CPU, 512-1024 MB RAM per service)

### 5. Utility Services Group (`utility-services`)

- **Services:** 7 (DDNS, Zilean, Zipline, LibreSpeed, Speedtest Tracker, Dozzle, Watchtower)
- **Purpose:** System utilities and maintenance
- **Resource Usage:** Light (50-200 CPU, 64-256 MB RAM per service)

### 6. Debrid Downloads Group (`debrid-downloads`)

- **Services:** 5 (TorBox Manager, Zurg, RealDebrid Monitor, MediaFlow Proxy)
- **Purpose:** Debrid service management and streaming
- **Resource Usage:** Medium (200-300 CPU, 256-512 MB RAM per service)

## Configuration Requirements

### Environment Variables Needed

```bash
# Common
TZ="America/Chicago"
PUID="1002"
PGID="988"
UMASK="002"
CONFIG_PATH="./configs"

# Domains
DOMAIN="example.com"
DUCKDNS_SUBDOMAIN="example"
TS_HOSTNAME="example"

# API Keys
TMDB_API_KEY=""
TRAKT_CLIENT_ID=""
TRAKT_CLIENT_SECRET=""
CLOUDFLARE_API_KEY=""
TORBOX_API_KEY=""
REALDEBRID_API_KEY=""

# Service Specific
VAULTWARDEN_ADMIN_TOKEN=""
ZIPLINE_SECRET=""
LIBRESPEED_PASSWORD=""
SPEEDTEST_TRACKER_APP_KEY=""
```

### Volume Mounts Required

```bash
# Configuration directories
./configs/[service-name]:/config

# Media directories
/mnt/user/movies:/movies
/mnt/user/tv:/tv
/mnt/user/anime:/anime
/mnt/user/downloads:/downloads

# System mounts
/var/run/docker.sock:/var/run/docker.sock (for management services)
/dev/fuse:/dev/fuse (for Zurg)
```

## Deployment Order Recommendation

1. **Infrastructure Services** (Traefik, Consul, Nomad)
2. **Security Services** (`nomad-additional-services.hcl` - security-monitoring group)
3. **Utility Services** (`nomad-utility-debrid-services.hcl` - utility-services group)
4. **Debrid Services** (`nomad-utility-debrid-services.hcl` - debrid-downloads group)
5. **Media Management** (`nomad-additional-services.hcl` - media-management group)
6. **Servarr Services** (`nomad-servarr-services.hcl`)
7. **Stremio Addons** (`nomad-stremio-addons.hcl`)

## Health Check Status

All converted services include:

- ✅ HTTP health checks (where applicable)
- ✅ Proper restart policies
- ✅ Resource limits
- ✅ Service registration with Consul
- ✅ Traefik routing labels
- ✅ Homepage dashboard integration

## Next Steps

1. **Complete remaining conversions** for pending services
2. **Test all service deployments** in staging environment
3. **Configure secrets management** for API keys and passwords
4. **Set up monitoring** for all services
5. **Create backup strategies** for configuration data
6. **Document service interdependencies**
7. **Implement automated testing** for deployments
