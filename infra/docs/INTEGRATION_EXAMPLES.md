# Integration Examples

This document provides real-world examples of using the canonical configuration system.

## Example 1: Basic Service Definition

```go
package main

import (
	"fmt"
	"log"

	infraconfig "cluster/infra/config"
)

func main() {
	// Load configuration
	cfg, err := infraconfig.LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Define a service using config helpers
	service := defineMyService(cfg)
	
	fmt.Printf("Service: %+v\n", service)
}

func defineMyService(cfg *infraconfig.Config) Service {
	// Build FQDN
	fqdn := infraconfig.BuildFQDN("my-api", cfg.NodeName, cfg.Domain)
	
	// Build URL
	url := infraconfig.BuildURL("my-api", cfg.Domain, true)
	
	// Resolve image name
	image := cfg.GetImageName("my-api:latest")
	
	// Build environment variables
	env := infraconfig.BuildEnvironmentMap(cfg, map[string]string{
		"API_URL": url,
		"LOG_LEVEL": "info",
	}, map[string]string{
		"CUSTOM_VAR": "custom-value",
	})
	
	// Build Traefik labels
	labels := infraconfig.BuildTraefikLabels(cfg, "my-api", infraconfig.TraefikLabelOptions{
		TLS: true,
		Port: "8080",
	})
	
	return Service{
		Name:          "my-api",
		Image:         image,
		ContainerName: "my-api",
		Networks:      []string{"publicnet", "backend"},
		Environment:   env,
		Labels:        labels,
		Healthcheck: &Healthcheck{
			Test:     []string{"CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"},
			Interval: "30s",
			Timeout:  "10s",
			Retries:  3,
		},
	}
}
```

## Example 2: Multi-Environment Configuration

```go
package main

import (
	"log"
	"os"

	infraconfig "cluster/infra/config"
)

func main() {
	// Determine environment
	env := os.Getenv("ENVIRONMENT")
	if env == "" {
		env = "development"
	}

	// Load environment-specific config
	configFile := fmt.Sprintf("config.%s.yaml", env)
	cfg, err := infraconfig.LoadConfig(configFile)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Check environment type
	if infraconfig.IsProduction(cfg) {
		log.Println("Running in production mode")
		// Production-specific setup
	} else if infraconfig.IsDevelopment(cfg) {
		log.Println("Running in development mode")
		// Development-specific setup
	}

	// Use configuration
	setupServices(cfg)
}

func setupServices(cfg *infraconfig.Config) {
	// Services are configured based on environment
	// Production might have different settings than development
}
```

## Example 3: Using Secret Manager

```go
package main

import (
	"fmt"
	"log"

	infraconfig "cluster/infra/config"
)

func main() {
	// Load configuration
	cfg, err := infraconfig.LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create secret manager from environment
	secretManager, err := infraconfig.NewSecretManagerFromEnv()
	if err != nil {
		log.Printf("Warning: Secret manager not available: %v", err)
		log.Println("Continuing without encryption...")
	} else {
		// Decrypt encrypted secrets in config
		if err := infraconfig.DecryptConfigSecrets(cfg, secretManager); err != nil {
			log.Printf("Warning: Failed to decrypt secrets: %v", err)
		}
	}

	// Use configuration with decrypted secrets
	useConfig(cfg)
}

func useConfig(cfg *infraconfig.Config) {
	// DNS API key is now decrypted if it was encrypted
	if cfg.DNS.APIKey != "" {
		fmt.Println("DNS API key is available")
	}
}
```

## Example 4: Encrypting Secrets for Storage

```go
package main

import (
	"fmt"
	"log"
	"os"

	infraconfig "cluster/infra/config"
)

func main() {
	// Get encryption key from environment
	encryptionKey := os.Getenv("CONFIG_ENCRYPTION_KEY")
	if encryptionKey == "" {
		log.Fatal("CONFIG_ENCRYPTION_KEY not set")
	}

	// Create secret manager
	salt := []byte("your-salt-here") // Use a secure salt in production
	sm := infraconfig.NewSecretManager(encryptionKey, salt)

	// Encrypt a secret
	apiKey := "your-api-key-here"
	encrypted, err := sm.EncryptConfigValue(apiKey)
	if err != nil {
		log.Fatalf("Failed to encrypt: %v", err)
	}

	fmt.Printf("Encrypted value: %s\n", encrypted)
	fmt.Println("You can now store this in your config.yaml file")
}
```

## Example 5: Custom Service Provider

```go
package main

import (
	infraconfig "cluster/infra/config"
)

// Define custom services
func defineCustomServices(cfg *infraconfig.Config) []infraconfig.ServiceConfig {
	return []infraconfig.ServiceConfig{
		{
			Name:          "custom-service",
			Image:         cfg.GetImageName("custom-service:latest"),
			ContainerName: "custom-service",
			Networks:      []string{"publicnet"},
			Environment: infraconfig.BuildEnvironmentMap(cfg, map[string]string{
				"SERVICE_NAME": "custom-service",
			}, nil),
			Labels: infraconfig.BuildTraefikLabels(cfg, "custom-service", infraconfig.TraefikLabelOptions{
				TLS:  true,
				Port: "8080",
			}),
		},
	}
}

func main() {
	// Load configuration
	cfg, _ := infraconfig.LoadConfig("config.yaml")

	// Create service registry
	registry := infraconfig.NewServiceRegistry()

	// Register custom service provider
	builtIn := infraconfig.NewBuiltInServiceProvider(
		defineCustomServices,
		// ... other service definers
	)
	registry.Register(builtIn)

	// Get all services
	services, _ := registry.GetServices(cfg)
	
	// Use services
	_ = services
}
```

## Example 6: Configuration Validation in CI/CD

```bash
#!/bin/bash
# validate-config.sh - CI/CD configuration validation

set -e

echo "Validating configuration files..."

# Validate main config
if ! ./config-tool -config config.yaml -validate; then
    echo "ERROR: Configuration validation failed!"
    exit 1
fi

# Validate production config
if ! ./config-tool -config config.production.yaml -validate; then
    echo "ERROR: Production configuration validation failed!"
    exit 1
fi

# Compare configs
echo "Comparing configurations..."
./config-tool -config config.yaml -diff config.production.yaml

echo "✓ All configurations are valid"
```

## Example 7: Dynamic Configuration Loading

```go
package main

import (
	"log"
	"time"

	infraconfig "cluster/infra/config"
)

func main() {
	// Load initial configuration
	cfg, err := infraconfig.LoadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Watch for configuration changes
	go watchConfig("config.yaml", func(newCfg *infraconfig.Config) {
		log.Println("Configuration reloaded")
		cfg = newCfg
		reloadServices(cfg)
	})

	// Main application loop
	runApplication(cfg)
}

func watchConfig(configPath string, callback func(*infraconfig.Config)) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		cfg, err := infraconfig.LoadConfig(configPath)
		if err != nil {
			log.Printf("Failed to reload config: %v", err)
			continue
		}
		callback(cfg)
	}
}

func reloadServices(cfg *infraconfig.Config) {
	// Reload services with new configuration
}

func runApplication(cfg *infraconfig.Config) {
	// Application logic
}
```

## Example 8: Using Configuration in Tests

```go
package main

import (
	"testing"

	infraconfig "cluster/infra/config"
)

func TestServiceDefinition(t *testing.T) {
	// Load test configuration
	cfg, err := infraconfig.LoadConfig("test-config.yaml")
	if err != nil {
		t.Fatalf("Failed to load test config: %v", err)
	}

	// Test service definition
	service := defineMyService(cfg)

	// Validate service
	if service.Name == "" {
		t.Error("Service name is required")
	}
	if service.Image == "" {
		t.Error("Service image is required")
	}

	// Test URL building
	url := infraconfig.BuildURL("my-api", cfg.Domain, true)
	if url == "" {
		t.Error("URL should not be empty")
	}
}

func TestEnvironmentDetection(t *testing.T) {
	// Test production detection
	prodCfg := &infraconfig.Config{
		Domain:     "example.com",
		ConfigPath: "/opt/infra/volumes",
		Registry: infraconfig.RegistryConfig{
			ImagePrefix: "docker.io/myorg",
		},
	}

	if !infraconfig.IsProduction(prodCfg) {
		t.Error("Should detect production environment")
	}

	// Test development detection
	devCfg := &infraconfig.Config{
		Domain:    "localhost",
		StackName: "dev",
	}

	if !infraconfig.IsDevelopment(devCfg) {
		t.Error("Should detect development environment")
	}
}
```

## Example 9: Configuration from Multiple Sources

```go
package main

import (
	"log"

	infraconfig "cluster/infra/config"
)

func main() {
	// Load base configuration
	baseCfg, err := infraconfig.LoadConfig("config.base.yaml")
	if err != nil {
		log.Fatalf("Failed to load base config: %v", err)
	}

	// Load environment-specific overrides
	envCfg, err := infraconfig.LoadConfig("config.production.yaml")
	if err != nil {
		log.Fatalf("Failed to load env config: %v", err)
	}

	// Merge configurations
	finalCfg := infraconfig.MergeConfigs(baseCfg, envCfg)

	// Use merged configuration
	useConfig(finalCfg)
}

func useConfig(cfg *infraconfig.Config) {
	// Configuration is merged from base + environment
}
```

## Example 10: Command-Line Tool Integration

```go
package main

import (
	"flag"
	"fmt"
	"log"

	infraconfig "cluster/infra/config"
)

func main() {
	configFile := flag.String("config", "", "Configuration file path")
	showSummary := flag.Bool("summary", false, "Show configuration summary")
	flag.Parse()

	// Load configuration
	cfg, err := infraconfig.LoadConfig(*configFile)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	if *showSummary {
		fmt.Print(infraconfig.GetConfigSummary(cfg))
		return
	}

	// Use configuration
	fmt.Printf("Domain: %s\n", cfg.Domain)
	fmt.Printf("Stack: %s\n", cfg.StackName)
}
```

## Best Practices

1. **Always validate configuration** before using it
2. **Use environment variables** for sensitive values
3. **Encrypt secrets** when storing in version control
4. **Use templates** for common scenarios
5. **Test configurations** in CI/CD pipelines
6. **Document custom configurations** for your team
7. **Use versioning** for configuration schema changes
8. **Separate concerns** - base config + environment overrides

## See Also

- `config/README.md` - Configuration system documentation
- `config/SCHEMA.md` - Complete schema reference
- `config/examples/` - Example configuration files
- `docs/MIGRATION_GUIDE.md` - Migration guide
