# Troubleshooting Guide

Common issues and solutions when using the canonical configuration system.

## Configuration Loading Issues

### Problem: Configuration file not found

**Symptoms:**
```
Error: failed to read config file: open config.yaml: no such file or directory
```

**Solutions:**
1. Check file path:
   ```bash
   ls -la config.yaml
   ```

2. Use absolute path:
   ```go
   cfg, err := config.LoadConfig("/full/path/to/config.yaml")
   ```

3. Check working directory:
   ```bash
   pwd
   # Ensure you're in the right directory
   ```

### Problem: YAML parsing errors

**Symptoms:**
```
Error: failed to parse YAML: yaml: line X: found character that cannot start any token
```

**Solutions:**
1. Validate YAML syntax:
   ```bash
   # Use a YAML validator
   yamllint config.yaml
   ```

2. Check indentation (YAML is sensitive to spaces):
   ```yaml
   # Correct
   traefik:
     web_port: 80
   
   # Incorrect (wrong indentation)
   traefik:
   web_port: 80
   ```

3. Check for special characters:
   ```yaml
   # Escape special characters if needed
   domain: "example.com"  # Quotes if needed
   ```

## Validation Errors

### Problem: Domain validation fails

**Symptoms:**
```
Error: domain 'invalid' is not a valid domain name
```

**Solutions:**
1. Use valid domain format:
   ```yaml
   domain: example.com  # ✅ Good
   domain: localhost     # ✅ Good
   domain: invalid       # ❌ Bad (no TLD)
   ```

2. Check for typos:
   ```bash
   ./config-tool -config config.yaml -show domain
   ```

### Problem: Port validation fails

**Symptoms:**
```
Error: port 70000 must be between 1 and 65535
```

**Solutions:**
1. Use valid port range:
   ```yaml
   traefik:
     web_port: 80        # ✅ Good
     web_port: 70000     # ❌ Bad (out of range)
   ```

2. Check for typos in port numbers

### Problem: Duplicate ports

**Symptoms:**
```
Error: port 8080 is used by multiple services: traefik.http_provider_port, cluster.api_port
```

**Solutions:**
1. Use unique ports:
   ```yaml
   traefik:
     http_provider_port: 8081
   cluster:
     api_port: 8080  # Different port
   ```

2. Check all port assignments:
   ```bash
   ./config-tool -config config.yaml -show cluster
   ./config-tool -config config.yaml -show traefik
   ```

### Problem: Stack name validation fails

**Symptoms:**
```
Error: stack_name 'my@stack' contains invalid characters
```

**Solutions:**
1. Use valid characters only:
   ```yaml
   stack_name: my-stack      # ✅ Good
   stack_name: my_stack      # ✅ Good
   stack_name: my@stack      # ❌ Bad
   ```

2. Use sanitization helper:
   ```go
   sanitized := config.SanitizeStackName("my@stack")
   // Returns: "mystack"
   ```

## Secret Management Issues

### Problem: Encryption key not set

**Symptoms:**
```
Error: CONFIG_ENCRYPTION_KEY environment variable not set
```

**Solutions:**
1. Set encryption key:
   ```bash
   export CONFIG_ENCRYPTION_KEY=your-secret-key
   ```

2. Use secure key management:
   ```bash
   # From file
   export CONFIG_ENCRYPTION_KEY=$(cat /secure/path/to/key)
   
   # From secrets manager
   export CONFIG_ENCRYPTION_KEY=$(aws secretsmanager get-secret-value ...)
   ```

### Problem: Decryption fails

**Symptoms:**
```
Error: failed to decrypt: cipher: message authentication failed
```

**Solutions:**
1. Check encryption key matches:
   ```bash
   # Must be the same key used for encryption
   echo $CONFIG_ENCRYPTION_KEY
   ```

2. Verify encrypted value format:
   ```yaml
   # Correct format
   dns:
     api_key: "encrypted:base64value"
   
   # Incorrect format
   dns:
     api_key: "base64value"  # Missing "encrypted:" prefix
   ```

3. Re-encrypt with correct key:
   ```go
   sm, _ := config.NewSecretManagerFromEnv()
   encrypted, _ := sm.EncryptConfigValue("your-secret")
   // Use new encrypted value
   ```

### Problem: Secret file permissions

**Symptoms:**
```
Error: failed to read secret file: permission denied
```

**Solutions:**
1. Check file permissions:
   ```bash
   ls -la secrets/api-key.txt
   # Should be 0600 (owner read/write only)
   ```

2. Fix permissions:
   ```bash
   chmod 600 secrets/api-key.txt
   ```

3. Check file ownership:
   ```bash
   ls -la secrets/
   # Ensure correct user owns the files
   ```

## Environment Variable Issues

### Problem: Environment variables not taking effect

**Symptoms:**
Configuration doesn't reflect environment variable values

**Solutions:**
1. Check variable is set:
   ```bash
   echo $DOMAIN
   ```

2. Check variable name (case-sensitive):
   ```bash
   # Correct
   export DOMAIN=example.com
   
   # Incorrect
   export domain=example.com  # Wrong case
   ```

3. Restart application after setting variables:
   ```bash
   export DOMAIN=example.com
   ./your-app  # New process picks up env vars
   ```

4. Check priority order:
   - Command-line flags > Environment variables > YAML > Defaults
   - If YAML has value, env var might not override it

## Service Definition Issues

### Problem: Image name not resolved correctly

**Symptoms:**
Image name doesn't include expected prefix

**Solutions:**
1. Check IMAGE_PREFIX is set:
   ```bash
   echo $IMAGE_PREFIX
   ```

2. Use GetImageName helper:
   ```go
   image := cfg.GetImageName("my-app:latest")
   // If IMAGE_PREFIX=docker.io/myorg
   // Result: docker.io/myorg/my-app:latest
   ```

3. Check if image already has registry:
   ```go
   // If image already has registry, prefix is not added
   image := cfg.GetImageName("docker.io/other/app:latest")
   // Result: docker.io/other/app:latest (unchanged)
   ```

### Problem: Traefik labels not generated correctly

**Symptoms:**
Traefik routing not working

**Solutions:**
1. Use BuildTraefikLabels helper:
   ```go
   labels := config.BuildTraefikLabels(cfg, "service", config.TraefikLabelOptions{
       TLS: true,
       Port: "8080",
   })
   ```

2. Check middleware configuration:
   ```yaml
   middlewares:
     error_pages_enabled: true
     crowdsec_enabled: true
   ```

3. Verify Traefik can read labels:
   ```bash
   docker inspect container-name | grep traefik
   ```

## Network Issues

### Problem: Network name incorrect

**Symptoms:**
Container can't connect to network

**Solutions:**
1. Use GetFullNetworkName helper:
   ```go
   networkName := cfg.GetFullNetworkName("publicnet")
   // Result: "infra_publicnet" (if stack_name is "infra")
   ```

2. Check network exists:
   ```bash
   docker network ls | grep publicnet
   ```

3. Verify stack name:
   ```yaml
   stack_name: infra  # Used in network naming
   ```

## Version Compatibility Issues

### Problem: Version mismatch error

**Symptoms:**
```
Error: configuration version 2.0 is not compatible with current version 1.0
```

**Solutions:**
1. Check configuration version:
   ```yaml
   version: "1.0"  # Should match supported version
   ```

2. Upgrade configuration:
   ```go
   upgraded, err := config.UpgradeConfig(cfg)
   ```

3. Use supported version:
   ```yaml
   # Currently only version 1.0 is supported
   version: "1.0"
   ```

## Performance Issues

### Problem: Configuration loading is slow

**Symptoms:**
Application startup is slow

**Solutions:**
1. Cache configuration:
   ```go
   var cachedConfig *config.Config
   
   func GetConfig() *config.Config {
       if cachedConfig == nil {
           cachedConfig, _ = config.LoadConfig("config.yaml")
       }
       return cachedConfig
   }
   ```

2. Use environment variables instead of YAML:
   ```bash
   # Faster than parsing YAML
   export DOMAIN=example.com
   ```

3. Minimize YAML file size:
   ```yaml
   # Only include what you need to override
   domain: example.com
   # Don't include defaults
   ```

## Debugging Tips

### Enable verbose output

```bash
# Show configuration details
./config-tool -config config.yaml

# Export and inspect
./config-tool -config config.yaml -export | jq .

# Compare with known good config
./config-tool -config config.yaml -diff config.good.yaml
```

### Check configuration state

```go
// Print configuration summary
fmt.Print(config.GetConfigSummary(cfg))

// Check environment detection
if config.IsProduction(cfg) {
    fmt.Println("Production mode")
}
```

### Validate step by step

```bash
# 1. Check file exists
ls -la config.yaml

# 2. Validate syntax
yamllint config.yaml

# 3. Validate configuration
./config-tool -config config.yaml -validate

# 4. Show configuration
./config-tool -config config.yaml
```

## Common Mistakes

### Mistake 1: Forgetting to validate

```go
// ❌ Bad
cfg, _ := config.LoadConfig("config.yaml")
// Errors discovered at runtime

// ✅ Good
cfg, err := config.LoadConfig("config.yaml")
if err != nil {
    log.Fatalf("Invalid config: %v", err)
}
```

### Mistake 2: Hardcoding values

```go
// ❌ Bad
domain := "example.com"

// ✅ Good
domain := cfg.Domain
```

### Mistake 3: Not using helpers

```go
// ❌ Bad
fqdn := fmt.Sprintf("%s.%s.%s", service, node, domain)

// ✅ Good
fqdn := config.BuildFQDN(service, cfg.NodeName, cfg.Domain)
```

### Mistake 4: Committing secrets

```yaml
# ❌ Bad
dns:
  api_key: "actual-secret-key"

# ✅ Good
dns:
  api_key: "encrypted:..."
# Or use environment variable
```

## Getting Help

1. **Check documentation:**
   - `config/README.md` - Main documentation
   - `config/SCHEMA.md` - Schema reference
   - `docs/QUICK_START.md` - Getting started

2. **Validate configuration:**
   ```bash
   ./config-tool -config config.yaml -validate
   ```

3. **Check examples:**
   - `config/examples/` - Example configurations
   - `docs/INTEGRATION_EXAMPLES.md` - Code examples

4. **Review error messages:**
   - Error messages include specific field names
   - Check the mentioned field in your config

5. **Compare with working config:**
   ```bash
   ./config-tool -config config.yaml -diff config.working.yaml
   ```

## Still Having Issues?

1. **Check logs:**
   ```bash
   # Enable verbose logging
   export LOG_LEVEL=debug
   ```

2. **Test with minimal config:**
   ```yaml
   # Minimal valid config
   domain: example.com
   stack_name: test
   ```

3. **Test with defaults:**
   ```go
   // Load with defaults only
   cfg, _ := config.LoadConfig("")
   ```

4. **Check version compatibility:**
   ```yaml
   version: "1.0"  # Ensure compatible version
   ```
