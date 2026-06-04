# Refactoring Guide: Making Infrastructure Code Canonical and Modular

## Overview

This guide documents the refactoring to make the infrastructure code more canonical, modular, and reusable. The goal is to remove hardcoded values and make everything configurable.

## Key Changes

### 1. Centralized Configuration System

**New Package**: `cluster/infra/config`

- **`config.go`**: Central configuration structure with all defaults
- **`service_registry.go`**: Plugin-like service registration system

### 2. Removed Hardcoded Values

**Before**:
```go
domain := getEnv("DOMAIN", "bolabaden.org")
stackName := getEnv("STACK_NAME", "my-media-stack")
middlewares := "bolabaden-error-pages@file,crowdsec@file,strip-www@file"
```

**After**:
```go
cfg, _ := config.LoadConfig("")
domain := cfg.Domain  // Default: "example.com"
stackName := cfg.StackName  // Default: "infra"
middlewares := cfg.GetTraefikMiddlewares()  // Configurable
```

### 3. Service Registry System

Services can now be registered programmatically:

```go
registry := config.NewServiceRegistry()
registry.Register(config.NewBuiltInServiceProvider(
    defineServicesCoolifyProxy,
    defineServicesWarp,
    // ... other service definers
))
services, _ := registry.GetServices(cfg)
```

### 4. Configuration Sources

Configuration can be loaded from:
1. Environment variables (highest priority)
2. YAML configuration file
3. Programmatic defaults

### 5. Image Registry Abstraction

**Before**:
```go
Image: "docker.io/bolabaden/ai-researchwizard-aio-fullstack:master"
```

**After**:
```go
Image: cfg.GetImageName("ai-researchwizard-aio-fullstack:master")
// Or with IMAGE_PREFIX env var: "docker.io/bolabaden/..."
```

## Migration Steps

### Step 1: Update Imports

```go
import "cluster/infra/config"
```

### Step 2: Load Configuration

```go
cfg, err := config.LoadConfig("config.yaml")  // Optional YAML file
if err != nil {
    log.Fatalf("Failed to load config: %v", err)
}
```

### Step 3: Replace Hardcoded Values

- `getEnv("DOMAIN", "bolabaden.org")` → `cfg.Domain`
- `getEnv("STACK_NAME", "my-media-stack")` → `cfg.StackName`
- Hardcoded middleware strings → `cfg.GetTraefikMiddlewares()`
- Hardcoded image names → `cfg.GetImageName(image)`

### Step 4: Use Helper Functions

```go
// Build FQDN
fqdn := config.BuildFQDN("service", cfg.NodeName, cfg.Domain)

// Build URL
url := config.BuildURL("service", cfg.Domain, true)  // HTTPS

// Build Traefik labels
labels := config.BuildTraefikLabels(cfg, "service", config.TraefikLabelOptions{
    TLS: true,
    Port: "8080",
})
```

## Configuration Structure

### Environment Variables

All configuration can be overridden via environment variables:

- `DOMAIN` - Primary domain (default: "example.com")
- `STACK_NAME` - Stack name (default: "infra")
- `TS_HOSTNAME` - Node name
- `CONFIG_PATH` - Configuration path
- `SECRETS_PATH` - Secrets path
- `IMAGE_PREFIX` - Docker image registry prefix
- `TRAEFIK_ERROR_PAGES_MIDDLEWARE` - Error pages middleware name
- `TRAEFIK_CROWDSEC_MIDDLEWARE` - Crowdsec middleware name
- `TRAEFIK_STRIP_WWW_MIDDLEWARE` - Strip WWW middleware name
- And many more...

### YAML Configuration

Example `config.yaml`:

```yaml
domain: example.com
stack_name: my-infra
node_name: node1

traefik:
  web_port: 80
  websecure_port: 443
  error_pages_middleware: "error-pages@file"
  crowdsec_middleware: "crowdsec@file"
  strip_www_middleware: "strip-www@file"

registry:
  image_prefix: "docker.io/myorg"
  default_registry: "docker.io"

middlewares:
  error_pages_enabled: true
  crowdsec_enabled: true
  strip_www_enabled: true

services:
  - name: my-service
    image: my-service:latest
    # ... service configuration
```

## Benefits

1. **Canonical**: Standard configuration structure
2. **Modular**: Services can be registered/extended
3. **Configurable**: Everything can be customized
4. **Reusable**: Can be used for any infrastructure
5. **Intuitive**: Clear structure and naming
6. **Robust**: Validation and error handling

## Backward Compatibility

The refactoring maintains backward compatibility:
- Environment variables still work
- Default values match previous behavior where possible
- Existing code continues to work with minimal changes

## Next Steps

1. Update all service definition files
2. Update main.go to use new config
3. Update cmd/agent/main.go to use new config
4. Create example configuration files
5. Update documentation

