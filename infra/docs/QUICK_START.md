# Quick Start Guide

Get started with the canonical configuration system in 5 minutes.

## Installation

### Prerequisites

- Go 1.24+ installed
- Docker (for running services)
- Basic understanding of YAML

### Build Tools

```bash
cd infra

# Build configuration tools
go build -o bin/config-tool ./cmd/config
go build -o bin/config-init ./cmd/config-init

# Or build everything
go build ./...
```

## Step 1: Generate Configuration

### Option A: Use the Wizard (Recommended)

```bash
go run ./cmd/config-init
```

The wizard will prompt you for:
- Domain name
- Stack name
- Node name
- Paths
- Traefik settings
- Cluster settings
- Registry settings

### Option B: Use a Template

```bash
# Copy a template
cp config/templates/development.yaml config.yaml

# Edit with your values
nano config.yaml
```

### Option C: Minimal Configuration

```bash
# Copy minimal example
cp config/examples/minimal.yaml config.yaml

# Edit domain and stack name
nano config.yaml
```

## Step 2: Validate Configuration

```bash
# Validate your configuration
./bin/config-tool -config config.yaml -validate
```

Expected output:
```
✓ Configuration is valid
```

## Step 3: Review Configuration

```bash
# Show full summary
./bin/config-tool -config config.yaml

# Show specific section
./bin/config-tool -config config.yaml -show traefik
./bin/config-tool -config config.yaml -show cluster
```

## Step 4: Use in Your Code

### Basic Example

```go
package main

import (
	"log"
	
	infraconfig "cluster/infra/config"
)

func main() {
	// Load configuration
	cfg, err := infraconfig.LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Use configuration
	log.Printf("Domain: %s", cfg.Domain)
	log.Printf("Stack: %s", cfg.StackName)
}
```

### With Environment Variables

```bash
# Set environment variables
export DOMAIN=mycompany.com
export STACK_NAME=production
export IMAGE_PREFIX=docker.io/myorg

# Run your application
go run main.go
```

### With Command-Line Flags (Agent)

```bash
# Use config file
./agent --config config.yaml

# Override with flags
./agent --config config.yaml --domain override.com
```

## Step 5: Encrypt Secrets (Optional)

### Encrypt a Secret

```go
package main

import (
	"fmt"
	"os"
	
	infraconfig "cluster/infra/config"
)

func main() {
	// Set encryption key
	os.Setenv("CONFIG_ENCRYPTION_KEY", "your-secret-key")
	
	// Create secret manager
	sm, _ := infraconfig.NewSecretManagerFromEnv()
	
	// Encrypt a value
	encrypted, _ := sm.EncryptConfigValue("my-api-key")
	fmt.Println(encrypted)
	
	// Use in config.yaml:
	// dns:
	//   api_key: "encrypted:..."
}
```

### Decrypt in Application

```go
cfg, _ := infraconfig.LoadConfig("config.yaml")

// Decrypt secrets automatically
secretManager, _ := infraconfig.NewSecretManagerFromEnv()
infraconfig.DecryptConfigSecrets(cfg, secretManager)

// Use decrypted secrets
apiKey := cfg.DNS.APIKey
```

## Common Tasks

### Change Domain

```yaml
# config.yaml
domain: newdomain.com
```

Or via environment:
```bash
export DOMAIN=newdomain.com
```

### Change Stack Name

```yaml
# config.yaml
stack_name: new-stack
```

### Customize Middleware Names

```yaml
# config.yaml
traefik:
  error_pages_middleware: "my-error-pages@file"
  crowdsec_middleware: "my-crowdsec@file"
```

### Set Image Prefix

```yaml
# config.yaml
registry:
  image_prefix: "docker.io/myorg"
```

Or via environment:
```bash
export IMAGE_PREFIX=docker.io/myorg
```

### Multi-Environment Setup

```bash
# Development
cp config/templates/development.yaml config.dev.yaml

# Production
cp config/templates/production.yaml config.prod.yaml

# Use in code
env := os.Getenv("ENVIRONMENT")
configFile := fmt.Sprintf("config.%s.yaml", env)
cfg, _ := infraconfig.LoadConfig(configFile)
```

## Next Steps

1. **Review Examples** - See `config/examples/` for more examples
2. **Read Documentation** - Check `config/README.md` for detailed docs
3. **Explore Integration** - See `docs/INTEGRATION_EXAMPLES.md` for real-world usage
4. **Customize** - Modify templates for your needs

## Troubleshooting

### Configuration Not Loading

```bash
# Check file exists
ls -la config.yaml

# Validate
./bin/config-tool -config config.yaml -validate

# Show config
./bin/config-tool -config config.yaml
```

### Validation Errors

```bash
# Get detailed errors
./bin/config-tool -config config.yaml -validate

# Common fixes:
# - Check domain name is valid
# - Ensure ports are unique
# - Verify paths exist
```

### Secret Decryption Fails

```bash
# Check encryption key is set
echo $CONFIG_ENCRYPTION_KEY

# Verify encrypted value format
# Should start with "encrypted:"
```

## Getting Help

- **Documentation**: `config/README.md`
- **Schema**: `config/SCHEMA.md`
- **Examples**: `config/examples/`
- **Integration**: `docs/INTEGRATION_EXAMPLES.md`
- **Migration**: `docs/MIGRATION_GUIDE.md`

## Example Workflow

```bash
# 1. Generate config
go run ./cmd/config-init
# Enter values when prompted
# Saves to config.yaml

# 2. Validate
./bin/config-tool -config config.yaml -validate

# 3. Review
./bin/config-tool -config config.yaml -show traefik

# 4. Use in code
# See integration examples

# 5. Deploy
# Your application now uses canonical config!
```

That's it! You're ready to use the canonical configuration system.
