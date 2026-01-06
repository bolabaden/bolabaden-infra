package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	infraconfig "cluster/infra/config"
	"gopkg.in/yaml.v3"
)

const configVersion = "1.0"

func main() {
	fmt.Println("Infrastructure Configuration Wizard")
	fmt.Println("====================================")
	fmt.Println()

	cfg := &infraconfig.Config{}

	// Core identity
	cfg.Domain = promptString("Domain name", "example.com")
	cfg.StackName = promptString("Stack name", "infra")
	cfg.NodeName = promptString("Node name (leave empty for hostname)", "")

	// Paths
	cfg.ConfigPath = promptString("Configuration path", "./volumes")
	cfg.SecretsPath = promptString("Secrets path", "./secrets")
	cfg.RootPath = promptString("Root path", ".")
	cfg.DataDir = promptString("Data directory", "/opt/constellation/data")

	// Traefik
	fmt.Println("\nTraefik Configuration:")
	cfg.Traefik.WebPort = promptInt("HTTP port", 80)
	cfg.Traefik.WebSecurePort = promptInt("HTTPS port", 443)
	cfg.Traefik.HTTPProviderPort = promptInt("HTTP provider port", 8081)
	cfg.Traefik.CertResolver = promptString("Certificate resolver", "letsencrypt")
	cfg.Traefik.ErrorPagesMiddleware = promptString("Error pages middleware", "error-pages@file")
	cfg.Traefik.CrowdsecMiddleware = promptString("Crowdsec middleware", "crowdsec@file")
	cfg.Traefik.StripWWWMiddleware = promptString("Strip WWW middleware", "strip-www@file")

	// Middlewares
	fmt.Println("\nMiddleware Configuration:")
	cfg.Middlewares.ErrorPagesEnabled = promptBool("Enable error pages middleware", true)
	cfg.Middlewares.CrowdsecEnabled = promptBool("Enable Crowdsec middleware", true)
	cfg.Middlewares.StripWWWEnabled = promptBool("Enable strip WWW middleware", true)

	// DNS
	fmt.Println("\nDNS Configuration:")
	cfg.DNS.Provider = promptChoice("DNS provider", []string{"cloudflare", "route53"}, "cloudflare")
	if cfg.DNS.Provider == "cloudflare" {
		fmt.Println("Note: Set CLOUDFLARE_API_KEY and CLOUDFLARE_ZONE_ID environment variables")
	}

	// Cluster
	fmt.Println("\nCluster Configuration:")
	cfg.Cluster.BindPort = promptInt("Gossip protocol port", 7946)
	cfg.Cluster.RaftPort = promptInt("Raft consensus port", 8300)
	cfg.Cluster.APIPort = promptInt("REST API port", 8080)
	cfg.Cluster.Priority = promptInt("Node priority (lower = higher priority)", 100)

	// Registry
	fmt.Println("\nRegistry Configuration:")
	cfg.Registry.ImagePrefix = promptString("Docker image prefix (leave empty for none)", "")
	cfg.Registry.DefaultRegistry = promptString("Default Docker registry", "docker.io")

	// DNS domain inherits from top-level domain
	if cfg.DNS.Domain == "" {
		cfg.DNS.Domain = cfg.Domain
	}

	// Validate configuration
	fmt.Println("\nValidating configuration...")
	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "Validation error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("✓ Configuration is valid")

	// Ask for output file
	outputFile := promptString("\nOutput file path", "config.yaml")

	// Create config with version
	configWithVersion := map[string]interface{}{
		"version": configVersion,
		"domain":  cfg.Domain,
		"stack_name": cfg.StackName,
		"node_name": cfg.NodeName,
		"config_path": cfg.ConfigPath,
		"secrets_path": cfg.SecretsPath,
		"root_path": cfg.RootPath,
		"data_dir": cfg.DataDir,
		"traefik": map[string]interface{}{
			"web_port":              cfg.Traefik.WebPort,
			"websecure_port":        cfg.Traefik.WebSecurePort,
			"error_pages_middleware": cfg.Traefik.ErrorPagesMiddleware,
			"crowdsec_middleware":   cfg.Traefik.CrowdsecMiddleware,
			"strip_www_middleware":  cfg.Traefik.StripWWWMiddleware,
			"cert_resolver":         cfg.Traefik.CertResolver,
			"http_provider_port":    cfg.Traefik.HTTPProviderPort,
		},
		"middlewares": map[string]interface{}{
			"error_pages_enabled": cfg.Middlewares.ErrorPagesEnabled,
			"error_pages_name":    cfg.Middlewares.ErrorPagesName,
			"crowdsec_enabled":    cfg.Middlewares.CrowdsecEnabled,
			"crowdsec_name":       cfg.Middlewares.CrowdsecName,
			"strip_www_enabled":   cfg.Middlewares.StripWWWEnabled,
			"strip_www_name":      cfg.Middlewares.StripWWWName,
		},
		"dns": map[string]interface{}{
			"provider": cfg.DNS.Provider,
			"domain":   cfg.DNS.Domain,
		},
		"cluster": map[string]interface{}{
			"bind_port": cfg.Cluster.BindPort,
			"raft_port": cfg.Cluster.RaftPort,
			"api_port":  cfg.Cluster.APIPort,
			"priority":  cfg.Cluster.Priority,
		},
		"registry": map[string]interface{}{
			"image_prefix":    cfg.Registry.ImagePrefix,
			"default_registry": cfg.Registry.DefaultRegistry,
		},
	}

	// Write YAML file
	data, err := yaml.Marshal(configWithVersion)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling config: %v\n", err)
		os.Exit(1)
	}

	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(outputFile), 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating directory: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(outputFile, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing config file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\n✓ Configuration saved to %s\n", outputFile)
	fmt.Println("\nNext steps:")
	fmt.Println("1. Review the configuration file")
	fmt.Println("2. Set required environment variables (e.g., CLOUDFLARE_API_KEY)")
	fmt.Println("3. Validate with: ./config-tool -config", outputFile, "-validate")
}

func promptString(prompt string, defaultValue string) string {
	reader := bufio.NewReader(os.Stdin)
	if defaultValue != "" {
		fmt.Printf("%s [%s]: ", prompt, defaultValue)
	} else {
		fmt.Printf("%s: ", prompt)
	}
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)
	if input == "" {
		return defaultValue
	}
	return input
}

func promptInt(prompt string, defaultValue int) int {
	reader := bufio.NewReader(os.Stdin)
	fmt.Printf("%s [%d]: ", prompt, defaultValue)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)
	if input == "" {
		return defaultValue
	}
	value, err := strconv.Atoi(input)
	if err != nil {
		fmt.Printf("Invalid number, using default %d\n", defaultValue)
		return defaultValue
	}
	return value
}

func promptBool(prompt string, defaultValue bool) bool {
	reader := bufio.NewReader(os.Stdin)
	defaultStr := "n"
	if defaultValue {
		defaultStr = "y"
	}
	fmt.Printf("%s [y/N]: ", prompt)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(strings.ToLower(input))
	if input == "" {
		return defaultValue
	}
	return input == "y" || input == "yes"
}

func promptChoice(prompt string, choices []string, defaultValue string) string {
	reader := bufio.NewReader(os.Stdin)
	fmt.Printf("%s (%s) [%s]: ", prompt, strings.Join(choices, "/"), defaultValue)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)
	if input == "" {
		return defaultValue
	}
	// Check if input is a valid choice
	for _, choice := range choices {
		if strings.EqualFold(input, choice) {
			return choice
		}
	}
	fmt.Printf("Invalid choice, using default %s\n", defaultValue)
	return defaultValue
}
