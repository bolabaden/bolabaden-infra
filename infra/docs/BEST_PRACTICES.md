# Configuration Best Practices

This guide outlines best practices for using the canonical configuration system.

## Configuration Management

### 1. Use Version Control

**Do:**
```bash
# Store configuration templates in version control
git add config/templates/
git add config/examples/
```

**Don't:**
```bash
# Don't commit secrets or production configs with real values
# Use .gitignore for sensitive files
echo "config.production.yaml" >> .gitignore
echo "secrets/" >> .gitignore
```

### 2. Separate Configuration by Environment

**Do:**
```
config/
  base.yaml          # Base configuration
  development.yaml   # Development overrides
  staging.yaml       # Staging overrides
  production.yaml    # Production overrides (gitignored)
```

**Don't:**
```yaml
# Don't mix environments in one file
domain: example.com  # Is this dev or prod?
```

### 3. Use Environment Variables for Secrets

**Do:**
```bash
# Set secrets via environment
export CLOUDFLARE_API_KEY=your-key
export CONFIG_ENCRYPTION_KEY=your-encryption-key
```

**Don't:**
```yaml
# Don't put secrets directly in YAML files
dns:
  api_key: "your-actual-key-here"  # ❌ Bad
```

### 4. Encrypt Secrets in Version Control

**Do:**
```yaml
# Encrypt secrets before committing
dns:
  api_key: "encrypted:base64encryptedvalue"
```

**Don't:**
```yaml
# Don't commit plaintext secrets
dns:
  api_key: "plaintext-secret"  # ❌ Bad
```

## Configuration Structure

### 1. Use Sensible Defaults

**Do:**
```go
// Use defaults, override only what's needed
cfg, _ := config.LoadConfig("")
// Most values have sensible defaults
```

**Don't:**
```yaml
# Don't override everything unnecessarily
traefik:
  web_port: 80  # This is already the default
```

### 2. Validate Early

**Do:**
```go
cfg, err := config.LoadConfig("config.yaml")
if err != nil {
    log.Fatalf("Invalid config: %v", err)
}
// Use validated config
```

**Don't:**
```go
// Don't skip validation
cfg, _ := config.LoadConfig("config.yaml")  // ❌ Bad
// Errors discovered at runtime
```

### 3. Use Helper Functions

**Do:**
```go
// Use helper functions
fqdn := config.BuildFQDN("api", cfg.NodeName, cfg.Domain)
url := config.BuildURL("api", cfg.Domain, true)
image := cfg.GetImageName("my-app:latest")
```

**Don't:**
```go
// Don't manually construct values
fqdn := fmt.Sprintf("api.%s.%s", nodeName, domain)  // ❌ Error-prone
```

## Security

### 1. Protect Encryption Keys

**Do:**
```bash
# Use secure key management
export CONFIG_ENCRYPTION_KEY=$(cat /secure/path/to/key)
# Or use a secrets manager
```

**Don't:**
```bash
# Don't hardcode keys
export CONFIG_ENCRYPTION_KEY="hardcoded-key"  # ❌ Bad
```

### 2. Restrict File Permissions

**Do:**
```go
// Secrets are written with 0600 permissions
config.WriteSecretToFile("/path/to/secret", value)
```

**Don't:**
```bash
# Don't use permissive permissions
chmod 644 secrets/api-key.txt  # ❌ Bad
```

### 3. Rotate Secrets Regularly

**Do:**
- Rotate encryption keys periodically
- Update API keys regularly
- Use short-lived credentials when possible

**Don't:**
- Don't use the same keys forever
- Don't share keys between environments

## Development Workflow

### 1. Use Development Templates

**Do:**
```bash
# Start with development template
cp config/templates/development.yaml config.yaml
```

**Don't:**
```bash
# Don't use production config for development
cp config.production.yaml config.yaml  # ❌ Bad
```

### 2. Validate in CI/CD

**Do:**
```bash
#!/bin/bash
# validate-config.sh
./config-tool -config config.yaml -validate || exit 1
```

**Don't:**
```bash
# Don't skip validation
# Deploy without checking  # ❌ Bad
```

### 3. Test Configuration Changes

**Do:**
```go
func TestConfig(t *testing.T) {
    cfg, err := config.LoadConfig("test-config.yaml")
    if err != nil {
        t.Fatalf("Config invalid: %v", err)
    }
    // Test with config
}
```

**Don't:**
```go
// Don't test with production config
cfg, _ := config.LoadConfig("config.production.yaml")  // ❌ Bad
```

## Performance

### 1. Cache Configuration

**Do:**
```go
var cachedConfig *config.Config

func GetConfig() *config.Config {
    if cachedConfig == nil {
        cachedConfig, _ = config.LoadConfig("config.yaml")
    }
    return cachedConfig
}
```

**Don't:**
```go
// Don't reload config on every request
func HandleRequest() {
    cfg, _ := config.LoadConfig("config.yaml")  // ❌ Slow
}
```

### 2. Use Environment Detection

**Do:**
```go
if config.IsProduction(cfg) {
    // Production optimizations
} else if config.IsDevelopment(cfg) {
    // Development features
}
```

**Don't:**
```go
// Don't hardcode environment checks
if os.Getenv("ENV") == "prod" {  // ❌ Fragile
}
```

## Documentation

### 1. Document Custom Configurations

**Do:**
```yaml
# config.yaml
# Custom configuration for multi-region deployment
# See docs/CUSTOM_SETUP.md for details
domain: example.com
```

**Don't:**
```yaml
# Undocumented custom values
domain: example.com
some_custom_field: value  # What is this?
```

### 2. Keep Examples Updated

**Do:**
- Update examples when adding features
- Test examples regularly
- Document breaking changes

**Don't:**
- Don't let examples become outdated
- Don't remove examples without replacement

## Error Handling

### 1. Validate on Startup

**Do:**
```go
func main() {
    cfg, err := config.LoadConfig("config.yaml")
    if err != nil {
        log.Fatalf("Invalid configuration: %v", err)
    }
    // Continue with valid config
}
```

**Don't:**
```go
// Don't ignore errors
cfg, _ := config.LoadConfig("config.yaml")  // ❌ Bad
// Errors discovered later
```

### 2. Provide Clear Error Messages

**Do:**
```go
if err := cfg.Validate(); err != nil {
    return fmt.Errorf("configuration validation failed: %w", err)
}
```

**Don't:**
```go
// Don't hide errors
if err := cfg.Validate(); err != nil {
    return err  // ❌ Not helpful
}
```

## Migration

### 1. Migrate Gradually

**Do:**
- Start with new services using new config
- Migrate existing services incrementally
- Test each migration step

**Don't:**
- Don't migrate everything at once
- Don't skip testing

### 2. Maintain Backward Compatibility

**Do:**
- Support old environment variables
- Provide migration guides
- Keep defaults compatible

**Don't:**
- Don't break existing deployments
- Don't remove features without notice

## Configuration Organization

### 1. Group Related Settings

**Do:**
```yaml
# Group related settings
traefik:
  web_port: 80
  websecure_port: 443
  cert_resolver: letsencrypt
```

**Don't:**
```yaml
# Don't scatter related settings
web_port: 80
# ... other unrelated settings ...
websecure_port: 443
```

### 2. Use Comments

**Do:**
```yaml
# Production configuration
# Last updated: 2024-01-01
domain: example.com
stack_name: production
```

**Don't:**
```yaml
# Uncommented configuration
domain: example.com  # What is this for?
```

## Testing

### 1. Test with Different Configurations

**Do:**
```go
func TestWithConfig(t *testing.T) {
    configs := []string{
        "test-config-dev.yaml",
        "test-config-prod.yaml",
    }
    for _, cfgFile := range configs {
        cfg, err := config.LoadConfig(cfgFile)
        // Test with each config
    }
}
```

**Don't:**
```go
// Don't test with only one config
func TestWithConfig(t *testing.T) {
    cfg, _ := config.LoadConfig("config.yaml")
    // Only tests one scenario
}
```

### 2. Test Validation

**Do:**
```go
func TestValidation(t *testing.T) {
    invalidConfig := &config.Config{
        Domain: "",  // Invalid
    }
    err := invalidConfig.Validate()
    if err == nil {
        t.Error("Should fail validation")
    }
}
```

## Summary

### Do's ✅

- Use version control for templates
- Separate configs by environment
- Use environment variables for secrets
- Encrypt secrets in version control
- Validate early and often
- Use helper functions
- Document custom configurations
- Test configuration changes
- Cache configuration
- Migrate gradually

### Don'ts ❌

- Don't commit secrets
- Don't mix environments
- Don't skip validation
- Don't hardcode values
- Don't ignore errors
- Don't use production config for dev
- Don't skip testing
- Don't break backward compatibility

## See Also

- `QUICK_START.md` - Getting started guide
- `config/README.md` - Configuration documentation
- `docs/INTEGRATION_EXAMPLES.md` - Usage examples
- `docs/MIGRATION_GUIDE.md` - Migration guide
