# Configuration System

This package provides a canonical, modular configuration system for the infrastructure codebase.

## Overview

The configuration system allows you to:
- Define all settings in a single place
- Override via environment variables
- Load from YAML files
- Use sensible defaults
- Extend with custom service definitions

## Quick Start

### Basic Usage

```go
import "cluster/infra/config"

// Load configuration (from env vars or YAML)
cfg, err := config.LoadConfig("config.yaml")
if err != nil {
    log.Fatalf("Failed to load config: %v", err)
}

// Use configuration
domain := cfg.Domain
stackName := cfg.StackName
```

### Environment Variables

All configuration can be overridden via environment variables:

```bash
export DOMAIN=mycompany.com
export STACK_NAME=production
export IMAGE_PREFIX=docker.io/mycompany
export TRAEFIK_ERROR_PAGES_MIDDLEWARE=my-error-pages@file
```

### YAML Configuration

Create a `config.yaml` file:

```yaml
domain: mycompany.com
stack_name: production

traefik:
  web_port: 80
  websecure_port: 443
  error_pages_middleware: "my-error-pages@file"

registry:
  image_prefix: "docker.io/mycompany"
```

Then load it:

```go
cfg, err := config.LoadConfig("config.yaml")
```

## Configuration Structure

### Core Identity

- `domain` - Primary domain (default: "example.com")
- `stack_name` - Stack name (default: "infra")
- `node_name` - Node name (default: hostname)

### Paths

- `config_path` - Configuration path (default: "./volumes")
- `secrets_path` - Secrets path (default: "./secrets")
- `root_path` - Root path (default: ".")
- `data_dir` - Data directory (default: "/opt/constellation/data")

### Traefik Configuration

- `traefik.web_port` - HTTP port (default: 80)
- `traefik.websecure_port` - HTTPS port (default: 443)
- `traefik.error_pages_middleware` - Error pages middleware name
- `traefik.crowdsec_middleware` - Crowdsec middleware name
- `traefik.strip_www_middleware` - Strip WWW middleware name
- `traefik.cert_resolver` - TLS certificate resolver (default: "letsencrypt")
- `traefik.http_provider_port` - HTTP provider API port (default: 8081)

### DNS Configuration

- `dns.provider` - DNS provider (default: "cloudflare")
- `dns.domain` - DNS domain (inherits from top-level domain if empty)
- `dns.api_key` - API key (set via `CLOUDFLARE_API_KEY` env var)
- `dns.zone_id` - Zone ID (set via `CLOUDFLARE_ZONE_ID` env var)

### Cluster Configuration

- `cluster.bind_port` - Gossip protocol port (default: 7946)
- `cluster.raft_port` - Raft consensus port (default: 8300)
- `cluster.api_port` - REST API port (default: 8080)
- `cluster.priority` - Node priority (default: 100)

### Registry Configuration

- `registry.image_prefix` - Docker image registry prefix
- `registry.default_registry` - Default registry (default: "docker.io")

## Helper Functions

### Build FQDN

```go
fqdn := config.BuildFQDN("service", cfg.NodeName, cfg.Domain)
// Result: "service.node1.example.com" or "service.example.com"
```

### Build URL

```go
url := config.BuildURL("service", cfg.Domain, true)
// Result: "https://service.example.com"
```

### Resolve Image Name

```go
image := config.ResolveImageName(cfg, "my-app:latest")
// If IMAGE_PREFIX="docker.io/myorg", result: "docker.io/myorg/my-app:latest"
// Otherwise: "my-app:latest"
```

### Build Traefik Labels

```go
labels := config.BuildTraefikLabels(cfg, "my-service", config.TraefikLabelOptions{
    TLS: true,
    Port: "8080",
    Middlewares: []string{"custom-middleware"},
})
```

### Build Traefik Command

```go
cmd := config.BuildTraefikCommand(cfg, tsHostname)
```

## Service Registry

The service registry allows you to register and discover service definitions:

```go
registry := config.NewServiceRegistry()

// Register built-in services
builtIn := config.NewBuiltInServiceProvider(
    defineServicesCoolifyProxy,
    defineServicesWarp,
    // ... other service definers
)
registry.Register(builtIn)

// Get all services
services, err := registry.GetServices(cfg)
```

## Migration from Old Config

If you have existing code using the old config system:

```go
// Old way
oldDomain := getEnv("DOMAIN", "bolabaden.org")

// New way
cfg := config.MigrateFromOldConfig(
    oldDomain,
    getEnv("STACK_NAME", "my-media-stack"),
    getEnv("CONFIG_PATH", "./volumes"),
    getEnv("SECRETS_PATH", "./secrets"),
    getEnv("ROOT_PATH", "."),
)

// Or better, use LoadConfig
cfg, _ := config.LoadConfig("")
```

## Environment Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Primary domain | "example.com" |
| `STACK_NAME` | Stack name | "infra" |
| `TS_HOSTNAME` | Node name | hostname |
| `CONFIG_PATH` | Configuration path | "./volumes" |
| `SECRETS_PATH` | Secrets path | "./secrets" |
| `ROOT_PATH` | Root path | "." |
| `DATA_DIR` | Data directory | "/opt/constellation/data" |
| `IMAGE_PREFIX` | Docker image registry prefix | "" |
| `TRAEFIK_ERROR_PAGES_MIDDLEWARE` | Error pages middleware | "error-pages@file" |
| `TRAEFIK_CROWDSEC_MIDDLEWARE` | Crowdsec middleware | "crowdsec@file" |
| `TRAEFIK_STRIP_WWW_MIDDLEWARE` | Strip WWW middleware | "strip-www@file" |
| `TRAEFIK_CERT_RESOLVER` | TLS certificate resolver | "letsencrypt" |
| `TRAEFIK_HTTP_PROVIDER_PORT` | HTTP provider port | 8081 |
| `DNS_PROVIDER` | DNS provider | "cloudflare" |
| `CLOUDFLARE_API_KEY` | Cloudflare API key | "" |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Zone ID | "" |
| `BIND_PORT` | Gossip protocol port | 7946 |
| `RAFT_PORT` | Raft consensus port | 8300 |
| `API_PORT` | REST API port | 8080 |
| `NODE_PRIORITY` | Node priority | 100 |

## Examples

See `example.go` for more detailed usage examples.

## See Also

- `REFACTORING_GUIDE.md` - Migration guide
- `CANONICAL_REFACTORING_SUMMARY.md` - Summary of changes
