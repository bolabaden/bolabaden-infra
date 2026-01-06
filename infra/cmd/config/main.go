package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	infraconfig "cluster/infra/config"
)

var (
	configFile = flag.String("config", "", "Path to configuration YAML file")
	validate   = flag.Bool("validate", false, "Validate configuration and exit")
	export     = flag.Bool("export", false, "Export configuration as JSON")
	show       = flag.String("show", "", "Show specific config section (domain, traefik, dns, cluster, registry)")
	diff       = flag.String("diff", "", "Compare with another config file")
)

func main() {
	flag.Parse()

	if *configFile == "" {
		*configFile = os.Getenv("CONFIG_FILE")
	}

	// Load configuration
	cfg, err := infraconfig.LoadConfig(*configFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading configuration: %v\n", err)
		os.Exit(1)
	}

	// Handle different commands
	if *validate {
		// Validation is already done in LoadConfig, but we can show success
		fmt.Println("✓ Configuration is valid")
		os.Exit(0)
	}

	if *export {
		exportConfig(cfg)
		os.Exit(0)
	}

	if *show != "" {
		showSection(cfg, *show)
		os.Exit(0)
	}

	if *diff != "" {
		diffConfigs(cfg, *diff)
		os.Exit(0)
	}

	// Default: show summary
	showSummary(cfg)
}

func showSummary(cfg *infraconfig.Config) {
	fmt.Println("Configuration Summary")
	fmt.Println("====================")
	fmt.Printf("Domain:        %s\n", cfg.Domain)
	fmt.Printf("Stack Name:    %s\n", cfg.StackName)
	fmt.Printf("Node Name:     %s\n", cfg.NodeName)
	fmt.Printf("Config Path:   %s\n", cfg.ConfigPath)
	fmt.Printf("Secrets Path:  %s\n", cfg.SecretsPath)
	fmt.Printf("Data Dir:      %s\n", cfg.DataDir)
	fmt.Println()
	fmt.Println("Traefik:")
	fmt.Printf("  Web Port:        %d\n", cfg.Traefik.WebPort)
	fmt.Printf("  WebSecure Port:  %d\n", cfg.Traefik.WebSecurePort)
	fmt.Printf("  HTTP Provider:   %d\n", cfg.Traefik.HTTPProviderPort)
	fmt.Printf("  Cert Resolver:   %s\n", cfg.Traefik.CertResolver)
	fmt.Printf("  Middlewares:     %s\n", cfg.GetTraefikMiddlewares())
	fmt.Println()
	fmt.Println("Cluster:")
	fmt.Printf("  Bind Port:  %d\n", cfg.Cluster.BindPort)
	fmt.Printf("  Raft Port:  %d\n", cfg.Cluster.RaftPort)
	fmt.Printf("  API Port:   %d\n", cfg.Cluster.APIPort)
	fmt.Printf("  Priority:   %d\n", cfg.Cluster.Priority)
	fmt.Println()
	fmt.Println("Registry:")
	fmt.Printf("  Image Prefix:     %s\n", cfg.Registry.ImagePrefix)
	fmt.Printf("  Default Registry:  %s\n", cfg.Registry.DefaultRegistry)
}

func showSection(cfg *infraconfig.Config, section string) {
	switch section {
	case "domain":
		fmt.Printf("Domain: %s\n", cfg.Domain)
		fmt.Printf("Stack Name: %s\n", cfg.StackName)
		fmt.Printf("Node Name: %s\n", cfg.NodeName)
	case "traefik":
		fmt.Println("Traefik Configuration:")
		fmt.Printf("  Web Port:        %d\n", cfg.Traefik.WebPort)
		fmt.Printf("  WebSecure Port:  %d\n", cfg.Traefik.WebSecurePort)
		fmt.Printf("  HTTP Provider:   %d\n", cfg.Traefik.HTTPProviderPort)
		fmt.Printf("  Cert Resolver:   %s\n", cfg.Traefik.CertResolver)
		fmt.Printf("  Error Pages:     %s\n", cfg.Traefik.ErrorPagesMiddleware)
		fmt.Printf("  Crowdsec:        %s\n", cfg.Traefik.CrowdsecMiddleware)
		fmt.Printf("  Strip WWW:       %s\n", cfg.Traefik.StripWWWMiddleware)
		fmt.Printf("  Middlewares:     %s\n", cfg.GetTraefikMiddlewares())
	case "dns":
		fmt.Println("DNS Configuration:")
		fmt.Printf("  Provider:  %s\n", cfg.DNS.Provider)
		fmt.Printf("  Domain:    %s\n", cfg.DNS.Domain)
		fmt.Printf("  Zone ID:   %s\n", maskSecret(cfg.DNS.ZoneID))
		fmt.Printf("  API Key:   %s\n", maskSecret(cfg.DNS.APIKey))
	case "cluster":
		fmt.Println("Cluster Configuration:")
		fmt.Printf("  Bind Port:     %d\n", cfg.Cluster.BindPort)
		fmt.Printf("  Raft Port:     %d\n", cfg.Cluster.RaftPort)
		fmt.Printf("  API Port:      %d\n", cfg.Cluster.APIPort)
		fmt.Printf("  Priority:      %d\n", cfg.Cluster.Priority)
		fmt.Printf("  Bind Addr:      %s\n", cfg.Cluster.BindAddr)
		fmt.Printf("  Public IP:      %s\n", cfg.Cluster.PublicIP)
		fmt.Printf("  Tailscale IP:   %s\n", cfg.Cluster.TailscaleIP)
	case "registry":
		fmt.Println("Registry Configuration:")
		fmt.Printf("  Image Prefix:     %s\n", cfg.Registry.ImagePrefix)
		fmt.Printf("  Default Registry:  %s\n", cfg.Registry.DefaultRegistry)
	default:
		fmt.Fprintf(os.Stderr, "Unknown section: %s\n", section)
		fmt.Fprintf(os.Stderr, "Available sections: domain, traefik, dns, cluster, registry\n")
		os.Exit(1)
	}
}

func exportConfig(cfg *infraconfig.Config) {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error exporting configuration: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(data))
}

func diffConfigs(cfg1 *infraconfig.Config, configFile2 string) {
	cfg2, err := infraconfig.LoadConfig(configFile2)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading second configuration: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Configuration Differences")
	fmt.Println("=========================")

	if cfg1.Domain != cfg2.Domain {
		fmt.Printf("Domain: %s -> %s\n", cfg1.Domain, cfg2.Domain)
	}
	if cfg1.StackName != cfg2.StackName {
		fmt.Printf("Stack Name: %s -> %s\n", cfg1.StackName, cfg2.StackName)
	}
	if cfg1.NodeName != cfg2.NodeName {
		fmt.Printf("Node Name: %s -> %s\n", cfg1.NodeName, cfg2.NodeName)
	}

	// Traefik differences
	if cfg1.Traefik.WebPort != cfg2.Traefik.WebPort {
		fmt.Printf("Traefik Web Port: %d -> %d\n", cfg1.Traefik.WebPort, cfg2.Traefik.WebPort)
	}
	if cfg1.Traefik.WebSecurePort != cfg2.Traefik.WebSecurePort {
		fmt.Printf("Traefik WebSecure Port: %d -> %d\n", cfg1.Traefik.WebSecurePort, cfg2.Traefik.WebSecurePort)
	}
	if cfg1.Traefik.CertResolver != cfg2.Traefik.CertResolver {
		fmt.Printf("Traefik Cert Resolver: %s -> %s\n", cfg1.Traefik.CertResolver, cfg2.Traefik.CertResolver)
	}

	// Cluster differences
	if cfg1.Cluster.BindPort != cfg2.Cluster.BindPort {
		fmt.Printf("Cluster Bind Port: %d -> %d\n", cfg1.Cluster.BindPort, cfg2.Cluster.BindPort)
	}
	if cfg1.Cluster.RaftPort != cfg2.Cluster.RaftPort {
		fmt.Printf("Cluster Raft Port: %d -> %d\n", cfg1.Cluster.RaftPort, cfg2.Cluster.RaftPort)
	}
	if cfg1.Cluster.APIPort != cfg2.Cluster.APIPort {
		fmt.Printf("Cluster API Port: %d -> %d\n", cfg1.Cluster.APIPort, cfg2.Cluster.APIPort)
	}

	// Registry differences
	if cfg1.Registry.ImagePrefix != cfg2.Registry.ImagePrefix {
		fmt.Printf("Registry Image Prefix: %s -> %s\n", cfg1.Registry.ImagePrefix, cfg2.Registry.ImagePrefix)
	}
}

func maskSecret(secret string) string {
	if secret == "" {
		return "(not set)"
	}
	if len(secret) <= 8 {
		return "***"
	}
	return secret[:4] + "..." + secret[len(secret)-4:]
}
