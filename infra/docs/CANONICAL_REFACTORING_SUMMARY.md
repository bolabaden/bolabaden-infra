# Canonical Refactoring Summary

## Overview

This document summarizes the refactoring to make the infrastructure code more canonical, modular, and reusable. The goal is to remove hardcoded values (like "bolabaden.org" and "my-media-stack") and make everything configurable.

## What Was Created

### 1. New `config` Package (`cluster/infra/config`)

**Files Created:**
- `config.go` - Central configuration structure with all defaults
- `service_registry.go` - Plugin-like service registration system
- `adapter.go` - Migration helpers and Traefik command builder
- `example.go` - Usage examples and documentation

**Key Features:**
- Centralized configuration with sensible defaults
- Environment variable support for all settings
- YAML configuration file support (structure defined)
- Service registry for extensible service definitions
- Helper functions for common operations

### 2. Configuration Structure

The new `Config` struct includes:
- **Core Identity**: Domain, StackName, NodeName
- **Paths**: ConfigPath, SecretsPath, RootPath, DataDir
- **Traefik**: Ports, middleware names, TLS settings
- **DNS**: Provider configuration
- **Cluster**: Network and API settings
- **Middlewares**: Configurable middleware names
- **Registry**: Docker image prefix configuration

### 3. Removed Hardcoded Values

**Before:**
```go
domain := getEnv("DOMAIN", "bolabaden.org")
stackName := getEnv("STACK_NAME", "my-media-stack")
middlewares := "bolabaden-error-pages@file,crowdsec@file,strip-www@file"
image := "docker.io/bolabaden/my-image:latest"
```

**After:**
```go
cfg, _ := config.LoadConfig("")
domain := cfg.Domain  // Default: "example.com"
stackName := cfg.StackName  // Default: "infra"
middlewares := cfg.GetTraefikMiddlewares()  // Configurable
image := cfg.GetImageName("my-image:latest")  // Uses IMAGE_PREFIX
```

## How to Use

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

### Service Registry

```go
// Create registry
registry := config.NewServiceRegistry()

// Register service providers
builtIn := config.NewBuiltInServiceProvider(
    defineServicesCoolifyProxy,
    defineServicesWarp,
    // ... other definers
)
registry.Register(builtIn)

// Get all services
services, err := registry.GetServices(cfg)
```

### Helper Functions

```go
// Build FQDN
fqdn := config.BuildFQDN("service", cfg.NodeName, cfg.Domain)

// Build URL
url := config.BuildURL("service", cfg.Domain, true)

// Resolve image name
image := config.ResolveImageName(cfg, "app:latest")

// Build Traefik labels
labels := config.BuildTraefikLabels(cfg, "service", config.TraefikLabelOptions{
    TLS: true,
    Port: "8080",
})
```

## Environment Variables

All configuration can be overridden via environment variables:

- `DOMAIN` - Primary domain (default: "example.com")
- `STACK_NAME` - Stack name (default: "infra")
- `TS_HOSTNAME` - Node name
- `IMAGE_PREFIX` - Docker image registry prefix
- `TRAEFIK_ERROR_PAGES_MIDDLEWARE` - Error pages middleware name
- `TRAEFIK_CROWDSEC_MIDDLEWARE` - Crowdsec middleware name
- `TRAEFIK_STRIP_WWW_MIDDLEWARE` - Strip WWW middleware name
- And many more...

## Migration Path

### Step 1: Update Imports
```go
import "cluster/infra/config"
```

### Step 2: Load Configuration
```go
cfg, err := config.LoadConfig("")
```

### Step 3: Replace Hardcoded Values
- Replace `getEnv("DOMAIN", "bolabaden.org")` with `cfg.Domain`
- Replace `getEnv("STACK_NAME", "my-media-stack")` with `cfg.StackName`
- Replace hardcoded middleware strings with `cfg.GetTraefikMiddlewares()`
- Replace hardcoded image names with `cfg.GetImageName(image)`

### Step 4: Use Helper Functions
- Use `config.BuildFQDN()` for FQDNs
- Use `config.BuildURL()` for URLs
- Use `config.BuildTraefikLabels()` for Traefik labels

## Benefits

1. **Canonical**: Standard configuration structure
2. **Modular**: Services can be registered/extended
3. **Configurable**: Everything can be customized
4. **Reusable**: Can be used for any infrastructure
5. **Intuitive**: Clear structure and naming
6. **Robust**: Validation and error handling

## Next Steps

To complete the refactoring:

1. Update `main.go` to use `config.LoadConfig()`
2. Update `cmd/agent/main.go` to use new config
3. Update all service definition files to use config helpers
4. Replace hardcoded middleware names in `services.go` and `services_coolify_proxy.go`
5. Replace hardcoded image names in service files
6. Update `buildTraefikCommand` to use `config.BuildTraefikCommand()`
7. Create example configuration files
8. Update tests to use new config system

## Files to Update

- `main.go` - Use `config.LoadConfig()`
- `cmd/agent/main.go` - Use new config
- `services.go` - Use config helpers
- `services_coolify_proxy.go` - Use config helpers
- `services_llm.go` - Use `cfg.GetImageName()`
- `services_warp.go` - Use `cfg.GetImageName()`
- All other service files - Use config helpers

## Testing

The new config package compiles successfully. Next steps:
1. Update existing code to use new config
2. Run tests to ensure compatibility
3. Create integration tests for config system

