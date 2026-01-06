# Configuration Cheat Sheet

Quick reference for the canonical configuration system.

## Quick Commands

```bash
# Generate configuration
make config-init
# or
go run ./cmd/config-init

# Validate configuration
make validate
# or
./bin/config-tool -config config.yaml -validate

# Show configuration
./bin/config-tool -config config.yaml

# Show specific section
./bin/config-tool -config config.yaml -show traefik

# Export as JSON
./bin/config-tool -config config.yaml -export

# Compare configs
./bin/config-tool -config config1.yaml -diff config2.yaml
```

## Configuration Structure

```yaml
version: "1.0"              # Configuration version
domain: example.com          # Primary domain
stack_name: infra           # Stack name
node_name: node1            # Node name (optional)

config_path: ./volumes      # Config path
secrets_path: ./secrets     # Secrets path
root_path: .                # Root path
data_dir: /opt/data         # Data directory

traefik:
  web_port: 80
  websecure_port: 443
  cert_resolver: letsencrypt
  http_provider_port: 8081

dns:
  provider: cloudflare
  domain: example.com

cluster:
  bind_port: 7946
  raft_port: 8300
  api_port: 8080
  priority: 100

registry:
  image_prefix: ""
  default_registry: docker.io
```

## Environment Variables

```bash
# Core
DOMAIN=example.com
STACK_NAME=infra
TS_HOSTNAME=node1

# Paths
CONFIG_PATH=./volumes
SECRETS_PATH=./secrets
ROOT_PATH=.
DATA_DIR=/opt/data

# Traefik
TRAEFIK_WEB_PORT=80
TRAEFIK_WEBSECURE_PORT=443
TRAEFIK_CERT_RESOLVER=letsencrypt
TRAEFIK_HTTP_PROVIDER_PORT=8081
TRAEFIK_ERROR_PAGES_MIDDLEWARE=error-pages@file
TRAEFIK_CROWDSEC_MIDDLEWARE=crowdsec@file
TRAEFIK_STRIP_WWW_MIDDLEWARE=strip-www@file

# DNS
DNS_PROVIDER=cloudflare
CLOUDFLARE_API_KEY=your-key
CLOUDFLARE_ZONE_ID=your-zone-id

# Cluster
BIND_PORT=7946
RAFT_PORT=8300
API_PORT=8080
NODE_PRIORITY=100

# Registry
IMAGE_PREFIX=docker.io/myorg
DEFAULT_REGISTRY=docker.io

# Secrets
CONFIG_ENCRYPTION_KEY=your-encryption-key
```

## Go Code Examples

### Load Configuration

```go
import infraconfig "cluster/infra/config"

// Load from file
cfg, err := infraconfig.LoadConfig("config.yaml")

// Load from environment only
cfg, err := infraconfig.LoadConfig("")
```

### Helper Functions

```go
// Build FQDN
fqdn := infraconfig.BuildFQDN("service", cfg.NodeName, cfg.Domain)

// Build URL
url := infraconfig.BuildURL("service", cfg.Domain, true)

// Resolve image
image := cfg.GetImageName("app:latest")

// Build Traefik labels
labels := infraconfig.BuildTraefikLabels(cfg, "service", infraconfig.TraefikLabelOptions{
    TLS: true,
    Port: "8080",
})

// Environment detection
if infraconfig.IsProduction(cfg) { }
if infraconfig.IsDevelopment(cfg) { }
```

### Secret Management

```go
// Create secret manager
sm, _ := infraconfig.NewSecretManagerFromEnv()

// Encrypt
encrypted, _ := sm.EncryptConfigValue("secret-value")

// Decrypt
decrypted, _ := sm.DecryptConfigValue("encrypted:...")

// Auto-decrypt config
infraconfig.DecryptConfigSecrets(cfg, sm)
```

## Common Patterns

### Multi-Environment

```go
env := os.Getenv("ENVIRONMENT")
configFile := fmt.Sprintf("config.%s.yaml", env)
cfg, _ := infraconfig.LoadConfig(configFile)
```

### Service Definition

```go
service := Service{
    Name:  "my-service",
    Image: cfg.GetImageName("my-service:latest"),
    Environment: infraconfig.BuildEnvironmentMap(cfg, defaults, overrides),
    Labels: infraconfig.BuildTraefikLabels(cfg, "my-service", options),
}
```

### Configuration Validation

```go
if err := cfg.Validate(); err != nil {
    log.Fatalf("Invalid config: %v", err)
}
```

## File Locations

```
infra/
  config/
    config.go              # Main config
    helpers.go             # Helper functions
    secrets.go             # Secret management
    service_registry.go    # Service registry
    README.md              # Documentation
    SCHEMA.md              # Schema docs
    example.yaml           # Example config
    templates/             # Templates
    examples/              # Examples
  cmd/
    config/                # Config tool
    config-init/           # Config wizard
    agent/                 # Agent
  docs/
    QUICK_START.md         # Quick start
    BEST_PRACTICES.md      # Best practices
    MIGRATION_GUIDE.md     # Migration guide
    INTEGRATION_EXAMPLES.md # Examples
    CHEAT_SHEET.md         # This file
```

## Validation Rules

- Domain: Valid domain name
- Stack name: Alphanumeric, hyphens, underscores
- Ports: 1-65535, must be unique
- Paths: Must be non-empty
- DNS provider: cloudflare or route53
- Registry: Valid registry name

## Default Values

- Domain: `example.com`
- Stack name: `infra`
- Node name: hostname
- Web port: `80`
- WebSecure port: `443`
- HTTP provider port: `8081`
- Bind port: `7946`
- Raft port: `8300`
- API port: `8080`
- Priority: `100`
- Default registry: `docker.io`

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Config not loading | Check file path, validate with `-validate` |
| Validation errors | Check domain, ports, paths |
| Secret decryption fails | Check `CONFIG_ENCRYPTION_KEY` |
| Port conflicts | Ensure ports are unique |
| Invalid domain | Use valid domain format |

## Quick Reference

### Priority Order
1. Command-line flags
2. Environment variables
3. YAML file
4. Defaults

### Encryption Format
```
encrypted:base64encodedvalue
```

### Version Format
```
version: "1.0"
```

### Network Naming
```
{stack_name}_{network_name}
```

### Image Naming
```
{image_prefix}/{image}
```

## See Also

- `QUICK_START.md` - Getting started
- `BEST_PRACTICES.md` - Best practices
- `config/README.md` - Full documentation
- `config/SCHEMA.md` - Complete schema
