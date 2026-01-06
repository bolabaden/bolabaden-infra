# Configuration Schema Documentation

This document describes the complete configuration schema for the infrastructure system.

## Root Level

### Core Identity

- `domain` (string, required): Primary domain name (e.g., "example.com")
  - Default: "example.com"
  - Validation: Must be a valid domain name

- `stack_name` (string, required): Stack name used for network and service naming
  - Default: "infra"
  - Validation: Must be alphanumeric, hyphens, or underscores only

- `node_name` (string, optional): Node name (defaults to hostname)
  - Default: "" (uses hostname)

### Paths

- `config_path` (string, required): Path to configuration files
  - Default: "./volumes"
  - Can be relative to `root_path`

- `secrets_path` (string, required): Path to secrets files
  - Default: "./secrets"
  - Can be relative to `root_path`

- `root_path` (string): Root path for resolving relative paths
  - Default: "."

- `data_dir` (string, required): Data directory for Raft and other persistent data
  - Default: "/opt/constellation/data"

## Traefik Configuration

```yaml
traefik:
  web_port: 80                    # HTTP port (1-65535)
  websecure_port: 443             # HTTPS port (1-65535)
  error_pages_middleware: "error-pages@file"  # Error pages middleware name
  crowdsec_middleware: "crowdsec@file"        # Crowdsec middleware name
  strip_www_middleware: "strip-www@file"     # Strip WWW middleware name
  cert_resolver: "letsencrypt"     # TLS certificate resolver
  http_provider_port: 8081         # HTTP provider API port (1-65535)
  cloudflare_trusted_ips:          # List of Cloudflare IP CIDR ranges
    - "103.21.244.0/22"
    - ...
```

### Validation Rules

- All ports must be between 1 and 65535
- Ports must be unique across all services
- Cloudflare trusted IPs must be valid CIDR ranges

## DNS Configuration

```yaml
dns:
  provider: "cloudflare"           # DNS provider (cloudflare, route53)
  domain: "example.com"           # DNS domain (inherits from root domain if empty)
  api_key: ""                     # API key (set via CLOUDFLARE_API_KEY env var)
  api_email: ""                   # API email (set via CLOUDFLARE_API_EMAIL env var)
  zone_id: ""                     # Zone ID (set via CLOUDFLARE_ZONE_ID env var)
```

### Supported Providers

- `cloudflare`: Cloudflare DNS
- `route53`: AWS Route 53 (future support)

## Cluster Configuration

```yaml
cluster:
  bind_addr: ""                   # Bind address (auto-detected if empty)
  bind_port: 7946                 # Gossip protocol port (1-65535)
  raft_port: 8300                 # Raft consensus port (1-65535)
  api_port: 8080                  # REST API port (1-65535)
  public_ip: ""                   # Public IP (auto-detected if empty)
  tailscale_ip: ""                # Tailscale IP (auto-detected if empty)
  priority: 100                   # Node priority (lower = higher priority)
```

### Validation Rules

- All ports must be between 1 and 65535
- Ports must be unique across all services

## Middleware Configuration

```yaml
middlewares:
  error_pages_enabled: true        # Enable error pages middleware
  error_pages_name: "error-pages"  # Error pages middleware name
  crowdsec_enabled: true          # Enable Crowdsec middleware
  crowdsec_name: "crowdsec"       # Crowdsec middleware name
  strip_www_enabled: true         # Enable strip WWW middleware
  strip_www_name: "strip-www"     # Strip WWW middleware name
```

## Registry Configuration

```yaml
registry:
  image_prefix: ""                # Docker image registry prefix
                                 # e.g., "docker.io/myorg" or "ghcr.io/user"
  default_registry: "docker.io"   # Default Docker registry
```

### Image Name Resolution

If `image_prefix` is set, images are prefixed automatically:
- Input: `my-app:latest`
- Output: `docker.io/myorg/my-app:latest` (if `image_prefix` is `docker.io/myorg`)

If an image already has a registry prefix, it is not modified.

## Network Configuration

```yaml
networks:
  network_name:
    name: "stack_network_name"    # Full network name
    driver: "bridge"               # Network driver
    subnet: "10.0.0.0/24"         # Subnet (optional)
    gateway: "10.0.0.1"           # Gateway (optional)
    bridge_name: "br_network"     # Bridge name (optional)
    external: false                # External network
    attachable: true               # Attachable network
```

## Service Configuration

```yaml
services:
  - name: "service-name"           # Service name
    image: "image:tag"             # Docker image
    container_name: "container"    # Container name
    hostname: "hostname"           # Container hostname
    networks:                      # List of networks
      - "network1"
      - "network2"
    ports:                         # Port mappings
      - host_port: "80"
        container_port: "8080"
        protocol: "tcp"
        host_ip: "0.0.0.0"
    volumes:                       # Volume mounts
      - source: "/host/path"
        target: "/container/path"
        read_only: false
        type: "bind"
    environment:                   # Environment variables
      KEY: "value"
    labels:                        # Docker labels
      label: "value"
    command: []                    # Command override
    entrypoint: []                 # Entrypoint override
    user: "user:group"             # User/group
    devices: []                    # Device mappings
    restart: "unless-stopped"     # Restart policy
    healthcheck:                   # Health check
      test: ["CMD-SHELL", "curl -f http://localhost/health"]
      interval: "30s"
      timeout: "10s"
      start_period: "0s"
      retries: 3
    depends_on: []                 # Service dependencies
    privileged: false              # Privileged mode
    cap_add: []                    # Added capabilities
    mem_limit: "1g"                # Memory limit
    mem_reservation: "512m"        # Memory reservation
    cpus: "2.0"                    # CPU limit
    extra_hosts: []                # Extra hosts
    build:                         # Build configuration
      context: "."
      dockerfile: "Dockerfile"
      args:
        ARG: "value"
    secrets:                       # Secret mounts
      - source: "/path/to/secret"
        target: "/container/path"
        mode: "0444"
    configs:                       # Config mounts
      - source: "/path/to/config"
        target: "/container/path"
        mode: "0444"
```

## Environment Variable Overrides

All configuration values can be overridden via environment variables. Environment variables take precedence over YAML configuration.

### Common Environment Variables

- `DOMAIN` - Primary domain
- `STACK_NAME` - Stack name
- `TS_HOSTNAME` - Node name
- `CONFIG_PATH` - Configuration path
- `SECRETS_PATH` - Secrets path
- `ROOT_PATH` - Root path
- `DATA_DIR` - Data directory
- `IMAGE_PREFIX` - Docker image registry prefix
- `TRAEFIK_ERROR_PAGES_MIDDLEWARE` - Error pages middleware name
- `TRAEFIK_CROWDSEC_MIDDLEWARE` - Crowdsec middleware name
- `TRAEFIK_STRIP_WWW_MIDDLEWARE` - Strip WWW middleware name
- `TRAEFIK_CERT_RESOLVER` - TLS certificate resolver
- `TRAEFIK_HTTP_PROVIDER_PORT` - HTTP provider port
- `DNS_PROVIDER` - DNS provider
- `CLOUDFLARE_API_KEY` - Cloudflare API key
- `CLOUDFLARE_ZONE_ID` - Cloudflare Zone ID
- `BIND_PORT` - Gossip protocol port
- `RAFT_PORT` - Raft consensus port
- `API_PORT` - REST API port
- `NODE_PRIORITY` - Node priority

## Configuration Priority

Configuration values are loaded in the following priority order (highest to lowest):

1. Command-line flags (for agent)
2. Environment variables
3. YAML configuration file
4. Programmatic defaults

## Validation

The configuration system performs comprehensive validation:

- Required fields are present
- Domain names are valid
- Stack names are valid
- Ports are in valid range (1-65535)
- Ports are unique
- Paths are valid
- DNS provider is supported
- Cloudflare IPs are valid CIDR ranges
- Registry names are valid

## Examples

See:
- `example.yaml` - Complete example
- `templates/production.yaml` - Production template
- `templates/development.yaml` - Development template
