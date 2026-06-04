package config

// Example usage of the new configuration system
// This demonstrates how to use the config package in a canonical way

/*
Example 1: Basic Configuration Loading

	cfg, err := config.LoadConfig("")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}
	
	// Use configuration
	domain := cfg.Domain
	stackName := cfg.StackName

Example 2: Loading from YAML File

	cfg, err := config.LoadConfig("/path/to/config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

Example 3: Using Service Registry

	// Create registry
	registry := config.NewServiceRegistry()
	
	// Register built-in services
	builtIn := config.NewBuiltInServiceProvider(
		defineServicesCoolifyProxy,
		defineServicesWarp,
		defineServicesHeadscale,
		// ... other service definers
	)
	registry.Register(builtIn)
	
	// Optionally register YAML-based services
	if yamlPath != "" {
		yamlProvider := config.NewYAMLServiceProvider(yamlPath)
		registry.Register(yamlProvider)
	}
	
	// Get all services
	services, err := registry.GetServices(cfg)
	if err != nil {
		log.Fatalf("Failed to get services: %v", err)
	}

Example 4: Building Traefik Command

	cfg, _ := config.LoadConfig("")
	tsHostname := cfg.NodeName
	cmd := config.BuildTraefikCommand(cfg, tsHostname)

Example 5: Using Helper Functions

	// Build FQDN
	fqdn := config.BuildFQDN("my-service", cfg.NodeName, cfg.Domain)
	// Result: "my-service.node1.example.com" or "my-service.example.com"
	
	// Build URL
	url := config.BuildURL("my-service", cfg.Domain, true)
	// Result: "https://my-service.example.com"
	
	// Resolve image name
	image := config.ResolveImageName(cfg, "my-app:latest")
	// If IMAGE_PREFIX="docker.io/myorg", result: "docker.io/myorg/my-app:latest"
	// Otherwise: "my-app:latest"
	
	// Build Traefik labels
	labels := config.BuildTraefikLabels(cfg, "my-service", config.TraefikLabelOptions{
		TLS:        true,
		Port:       "8080",
		Middlewares: []string{"custom-middleware"},
	})

Example 6: Custom Service Definer

	func defineMyCustomServices(cfg *config.Config) []config.ServiceConfig {
		return []config.ServiceConfig{
			{
				Name:          "my-service",
				Image:         config.ResolveImageName(cfg, "my-service:latest"),
				ContainerName: "my-service",
				Networks:      []string{"publicnet", "backend"},
				Environment: config.BuildEnvMap(cfg, map[string]string{
					"SERVICE_NAME": "my-service",
					"LOG_LEVEL":    "info",
				}, map[string]string{
					"CUSTOM_VAR": "custom-value",
				}),
				Labels: config.BuildTraefikLabels(cfg, "my-service", config.TraefikLabelOptions{
					TLS:  true,
					Port: "8080",
				}),
			},
		}
	}
	
	// Register it
	builtIn.AddDefiner(defineMyCustomServices)

Example 7: Environment Variable Overrides

	// All configuration can be overridden via environment variables
	export DOMAIN=mycompany.com
	export STACK_NAME=production
	export IMAGE_PREFIX=docker.io/mycompany
	export TRAEFIK_ERROR_PAGES_MIDDLEWARE=my-error-pages@file
	export TRAEFIK_CROWDSEC_MIDDLEWARE=my-crowdsec@file
	
	cfg, _ := config.LoadConfig("")
	// cfg.Domain = "mycompany.com"
	// cfg.StackName = "production"
	// cfg.Registry.ImagePrefix = "docker.io/mycompany"
	// cfg.Traefik.ErrorPagesMiddleware = "my-error-pages@file"

Example 8: Migration from Old Config

	// Old way
	oldDomain := getEnv("DOMAIN", "bolabaden.org")
	oldStackName := getEnv("STACK_NAME", "my-media-stack")
	
	// New way
	cfg := config.MigrateFromOldConfig(
		oldDomain,
		oldStackName,
		getEnv("CONFIG_PATH", "./volumes"),
		getEnv("SECRETS_PATH", "./secrets"),
		getEnv("ROOT_PATH", "."),
	)
	
	// Or better, use LoadConfig
	cfg, _ := config.LoadConfig("")

*/

