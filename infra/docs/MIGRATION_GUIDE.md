# Migration Guide: From Hardcoded to Canonical Configuration

This guide helps you migrate from the old hardcoded configuration system to the new canonical configuration system.

## Overview

The new configuration system provides:
- Centralized configuration management
- Environment variable overrides
- YAML file support
- Comprehensive validation
- Versioning support

## Quick Migration

### Step 1: Generate Initial Configuration

Use the configuration wizard to generate a base configuration:

```bash
go run ./cmd/config-init
```

Or use a template:

```bash
cp config/templates/production.yaml config.yaml
# Edit config.yaml with your values
```

### Step 2: Update Environment Variables

The new system uses the same environment variables, but with better defaults:

**Before:**
```bash
export DOMAIN=bolabaden.org
export STACK_NAME=my-media-stack
```

**After:**
```bash
export DOMAIN=yourdomain.com
export STACK_NAME=your-stack
# Or use config.yaml file
```

### Step 3: Validate Configuration

```bash
./config-tool -config config.yaml -validate
```

### Step 4: Update Code (if needed)

Most code automatically uses the new config system. If you have custom code:

**Before:**
```go
domain := getEnv("DOMAIN", "bolabaden.org")
stackName := getEnv("STACK_NAME", "my-media-stack")
```

**After:**
```go
import infraconfig "cluster/infra/config"

cfg, err := infraconfig.LoadConfig("config.yaml")
if err != nil {
    log.Fatalf("Failed to load config: %v", err)
}
domain := cfg.Domain
stackName := cfg.StackName
```

## Detailed Migration Steps

### 1. Domain and Stack Name

**Old:**
- Hardcoded: `"bolabaden.org"`, `"my-media-stack"`
- Environment: `DOMAIN`, `STACK_NAME`

**New:**
- Default: `"example.com"`, `"infra"`
- Configurable via YAML or environment variables
- Validated for correctness

**Migration:**
```yaml
# config.yaml
domain: yourdomain.com
stack_name: your-stack
```

### 2. Middleware Names

**Old:**
- Hardcoded: `"bolabaden-error-pages@file"`

**New:**
- Default: `"error-pages@file"`
- Configurable via `TRAEFIK_ERROR_PAGES_MIDDLEWARE`

**Migration:**
```yaml
# config.yaml
traefik:
  error_pages_middleware: "your-error-pages@file"
```

Or set environment variable:
```bash
export TRAEFIK_ERROR_PAGES_MIDDLEWARE=your-error-pages@file
```

### 3. Image Prefixes

**Old:**
- Hardcoded: `"docker.io/bolabaden"`

**New:**
- Default: `""` (no prefix)
- Configurable via `IMAGE_PREFIX`

**Migration:**
```yaml
# config.yaml
registry:
  image_prefix: "docker.io/yourorg"
```

Or set environment variable:
```bash
export IMAGE_PREFIX=docker.io/yourorg
```

### 4. Service Definitions

**Old:**
```go
Image: "docker.io/bolabaden/my-image:latest"
```

**New:**
```go
Image: cfg.GetImageName("my-image:latest")
```

**Migration:**
- Update service definition files to use `cfg.GetImageName()`
- Set `IMAGE_PREFIX` in config or environment

### 5. Traefik Command

**Old:**
```go
cmd := buildTraefikCommand(config)
```

**New:**
```go
cmd := infraconfig.BuildTraefikCommand(cfg, tsHostname)
```

**Migration:**
- Already updated in `services.go` and `services_coolify_proxy.go`
- No action needed if using standard service definitions

## Configuration File Examples

### Minimal Configuration

```yaml
domain: yourdomain.com
stack_name: your-stack
```

### Production Configuration

```yaml
domain: yourdomain.com
stack_name: production
node_name: node1

config_path: /opt/infra/volumes
secrets_path: /opt/infra/secrets
data_dir: /opt/infra/data

traefik:
  web_port: 80
  websecure_port: 443
  cert_resolver: letsencrypt

registry:
  image_prefix: "docker.io/yourorg"
```

### Development Configuration

```yaml
domain: localhost
stack_name: dev

config_path: ./volumes
secrets_path: ./secrets
data_dir: ./data

middlewares:
  crowdsec_enabled: false  # Disable for local dev
```

## Environment Variable Mapping

| Old Variable | New Variable | Default | Notes |
|-------------|--------------|---------|-------|
| `DOMAIN` | `DOMAIN` | `example.com` | Same |
| `STACK_NAME` | `STACK_NAME` | `infra` | Same |
| `TS_HOSTNAME` | `TS_HOSTNAME` | hostname | Same |
| N/A | `CONFIG_FILE` | `""` | Path to YAML config |
| N/A | `IMAGE_PREFIX` | `""` | Docker image prefix |
| N/A | `TRAEFIK_ERROR_PAGES_MIDDLEWARE` | `error-pages@file` | Customizable |
| N/A | `TRAEFIK_CROWDSEC_MIDDLEWARE` | `crowdsec@file` | Customizable |
| N/A | `TRAEFIK_STRIP_WWW_MIDDLEWARE` | `strip-www@file` | Customizable |

## Validation

The new system validates:
- Domain names
- Stack names
- Port ranges (1-65535)
- Port uniqueness
- DNS providers
- Registry names

**Before:**
- No validation
- Errors discovered at runtime

**After:**
- Comprehensive validation
- Errors caught early

```bash
# Validate configuration
./config-tool -config config.yaml -validate
```

## Backward Compatibility

The new system maintains backward compatibility:

1. **Environment variables still work** - All old environment variables are supported
2. **Default values** - Sensible defaults match common use cases
3. **Gradual migration** - You can migrate incrementally

### Migration Strategy

**Option 1: Environment Variables Only (No Changes)**
- Keep using environment variables
- No code changes needed
- Works immediately

**Option 2: YAML Configuration (Recommended)**
- Create `config.yaml` file
- Move environment variables to YAML
- Use `CONFIG_FILE` environment variable or `--config` flag

**Option 3: Hybrid**
- Use YAML for base configuration
- Override with environment variables
- Best of both worlds

## Troubleshooting

### Configuration Not Loading

```bash
# Check if file exists
ls -la config.yaml

# Validate configuration
./config-tool -config config.yaml -validate

# Show configuration
./config-tool -config config.yaml
```

### Validation Errors

```bash
# Get detailed error message
./config-tool -config config.yaml -validate

# Common issues:
# - Invalid domain name
# - Duplicate ports
# - Invalid port range
```

### Version Compatibility

The configuration system supports versioning:

```yaml
version: "1.0"
domain: example.com
...
```

If you see version errors, ensure your config file has a compatible version.

## Testing Migration

1. **Generate test configuration:**
   ```bash
   go run ./cmd/config-init
   ```

2. **Validate:**
   ```bash
   ./config-tool -config config.yaml -validate
   ```

3. **Compare with old values:**
   ```bash
   # Export old config (if you have one)
   ./config-tool -config old-config.yaml -export > old.json
   
   # Export new config
   ./config-tool -config config.yaml -export > new.json
   
   # Compare
   diff old.json new.json
   ```

4. **Test in development:**
   - Use development template
   - Test with `localhost` domain
   - Verify all services work

5. **Deploy to production:**
   - Use production template
   - Set environment variables
   - Monitor for issues

## Next Steps

After migration:

1. **Review configuration** - Ensure all values are correct
2. **Document custom settings** - Note any non-standard configurations
3. **Set up CI/CD validation** - Add config validation to your pipeline
4. **Backup configuration** - Store config files in version control (without secrets)

## Support

For issues or questions:
1. Check `config/README.md` for usage examples
2. Review `config/SCHEMA.md` for schema documentation
3. See `config/examples/` for example configurations
4. Use `./config-tool -help` for CLI help
