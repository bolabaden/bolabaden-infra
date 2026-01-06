package config

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Config holds all configuration for the infrastructure system
// This is the canonical configuration structure that can be loaded from
// environment variables, YAML files, or programmatically
type Config struct {
	// Core identity
	Domain    string `yaml:"domain" env:"DOMAIN" default:"example.com"`
	StackName string `yaml:"stack_name" env:"STACK_NAME" default:"infra"`
	NodeName  string `yaml:"node_name" env:"TS_HOSTNAME" default:""`

	// Paths
	ConfigPath  string `yaml:"config_path" env:"CONFIG_PATH" default:"./volumes"`
	SecretsPath string `yaml:"secrets_path" env:"SECRETS_PATH" default:"./secrets"`
	RootPath    string `yaml:"root_path" env:"ROOT_PATH" default:"."`
	DataDir     string `yaml:"data_dir" env:"DATA_DIR" default:"/opt/constellation/data"`

	// Network configuration
	Networks map[string]NetworkConfig `yaml:"networks"`

	// Service configuration
	Services []ServiceConfig `yaml:"services"`

	// Traefik configuration
	Traefik TraefikConfig `yaml:"traefik"`

	// DNS configuration
	DNS DNSConfig `yaml:"dns"`

	// Cluster configuration
	Cluster ClusterConfig `yaml:"cluster"`

	// Middleware configuration
	Middlewares MiddlewareConfig `yaml:"middlewares"`

	// Docker registry configuration
	Registry RegistryConfig `yaml:"registry"`
}

// NetworkConfig defines a Docker network
type NetworkConfig struct {
	Name       string `yaml:"name"`
	Driver     string `yaml:"driver" default:"bridge"`
	Subnet     string `yaml:"subnet"`
	Gateway    string `yaml:"gateway"`
	BridgeName string `yaml:"bridge_name"`
	External   bool   `yaml:"external" default:"false"`
	Attachable bool   `yaml:"attachable" default:"true"`
}

// ServiceConfig defines a service that can be deployed
// This is extensible - users can define their own services
type ServiceConfig struct {
	Name           string            `yaml:"name"`
	Image          string            `yaml:"image"`
	ContainerName  string            `yaml:"container_name"`
	Hostname       string            `yaml:"hostname"`
	Networks       []string          `yaml:"networks"`
	Ports          []PortMapping     `yaml:"ports"`
	Volumes        []VolumeMount     `yaml:"volumes"`
	Environment    map[string]string `yaml:"environment"`
	Labels         map[string]string `yaml:"labels"`
	Command        []string          `yaml:"command"`
	Entrypoint     []string          `yaml:"entrypoint"`
	User           string            `yaml:"user"`
	Devices        []string          `yaml:"devices"`
	Restart        string            `yaml:"restart" default:"unless-stopped"`
	Healthcheck    *Healthcheck      `yaml:"healthcheck"`
	DependsOn      []string          `yaml:"depends_on"`
	Privileged     bool              `yaml:"privileged" default:"false"`
	CapAdd         []string          `yaml:"cap_add"`
	MemLimit       string            `yaml:"mem_limit"`
	MemReservation string            `yaml:"mem_reservation"`
	CPUs           string            `yaml:"cpus"`
	ExtraHosts     []string          `yaml:"extra_hosts"`
	Build          *BuildConfig      `yaml:"build"`
	Secrets        []SecretMount     `yaml:"secrets"`
	Configs        []ConfigMount     `yaml:"configs"`
}

// PortMapping defines port mappings
type PortMapping struct {
	HostPort      string `yaml:"host_port"`
	ContainerPort string `yaml:"container_port"`
	Protocol      string `yaml:"protocol" default:"tcp"`
	HostIP        string `yaml:"host_ip" default:"0.0.0.0"`
}

// VolumeMount defines volume mounts
type VolumeMount struct {
	Source   string `yaml:"source"`
	Target   string `yaml:"target"`
	ReadOnly bool   `yaml:"read_only" default:"false"`
	Type     string `yaml:"type" default:"bind"` // bind, volume, tmpfs
}

// SecretMount defines secret mounts
type SecretMount struct {
	Source string `yaml:"source"`
	Target string `yaml:"target"`
	Mode   string `yaml:"mode" default:"0444"`
}

// ConfigMount defines config mounts
type ConfigMount struct {
	Source string `yaml:"source"`
	Target string `yaml:"target"`
	Mode   string `yaml:"mode" default:"0444"`
}

// BuildConfig defines build configuration
type BuildConfig struct {
	Context    string            `yaml:"context"`
	Dockerfile string            `yaml:"dockerfile"`
	Args       map[string]string `yaml:"args"`
}

// Healthcheck defines health check configuration
type Healthcheck struct {
	Test        []string `yaml:"test"`
	Interval    string   `yaml:"interval" default:"30s"`
	Timeout     string   `yaml:"timeout" default:"10s"`
	StartPeriod string   `yaml:"start_period" default:"0s"`
	Retries     int      `yaml:"retries" default:"3"`
}

// TraefikConfig holds Traefik-specific configuration
type TraefikConfig struct {
	// Entry points
	WebPort       int `yaml:"web_port" env:"TRAEFIK_WEB_PORT" default:"80"`
	WebSecurePort int `yaml:"websecure_port" env:"TRAEFIK_WEBSECURE_PORT" default:"443"`

	// Middleware names (configurable)
	ErrorPagesMiddleware string `yaml:"error_pages_middleware" env:"TRAEFIK_ERROR_PAGES_MIDDLEWARE" default:"error-pages@file"`
	CrowdsecMiddleware   string `yaml:"crowdsec_middleware" env:"TRAEFIK_CROWDSEC_MIDDLEWARE" default:"crowdsec@file"`
	StripWWWMiddleware   string `yaml:"strip_www_middleware" env:"TRAEFIK_STRIP_WWW_MIDDLEWARE" default:"strip-www@file"`

	// TLS configuration
	CertResolver string `yaml:"cert_resolver" env:"TRAEFIK_CERT_RESOLVER" default:"letsencrypt"`

	// Cloudflare trusted IPs (for forwarded headers)
	CloudflareTrustedIPs []string `yaml:"cloudflare_trusted_ips"`

	// HTTP provider
	HTTPProviderPort int `yaml:"http_provider_port" env:"TRAEFIK_HTTP_PROVIDER_PORT" default:"8081"`
}

// DNSConfig holds DNS provider configuration
type DNSConfig struct {
	Provider string `yaml:"provider" env:"DNS_PROVIDER" default:"cloudflare"` // cloudflare, route53, etc.
	Domain   string `yaml:"domain"`                                           // Inherits from top-level domain if empty
	APIKey   string `yaml:"api_key" env:"CLOUDFLARE_API_KEY"`
	APIEmail string `yaml:"api_email" env:"CLOUDFLARE_API_EMAIL"`
	ZoneID   string `yaml:"zone_id" env:"CLOUDFLARE_ZONE_ID"`
}

// ClusterConfig holds cluster configuration
type ClusterConfig struct {
	BindAddr    string `yaml:"bind_addr" env:"BIND_ADDR" default:""`
	BindPort    int    `yaml:"bind_port" env:"BIND_PORT" default:"7946"`
	RaftPort    int    `yaml:"raft_port" env:"RAFT_PORT" default:"8300"`
	APIPort     int    `yaml:"api_port" env:"API_PORT" default:"8080"`
	PublicIP    string `yaml:"public_ip" env:"PUBLIC_IP" default:""`
	TailscaleIP string `yaml:"tailscale_ip" env:"TAILSCALE_IP" default:""`
	Priority    int    `yaml:"priority" env:"NODE_PRIORITY" default:"100"`
}

// MiddlewareConfig holds middleware configuration
type MiddlewareConfig struct {
	// Error pages configuration
	ErrorPagesEnabled bool   `yaml:"error_pages_enabled" default:"true"`
	ErrorPagesName    string `yaml:"error_pages_name" default:"error-pages"`

	// Crowdsec configuration
	CrowdsecEnabled bool   `yaml:"crowdsec_enabled" default:"true"`
	CrowdsecName    string `yaml:"crowdsec_name" default:"crowdsec"`

	// Strip WWW configuration
	StripWWWEnabled bool   `yaml:"strip_www_enabled" default:"true"`
	StripWWWName    string `yaml:"strip_www_name" default:"strip-www"`
}

// RegistryConfig holds Docker registry configuration
type RegistryConfig struct {
	// Default registry prefix for images
	// e.g., "docker.io/bolabaden" or "ghcr.io/user" or empty for public images
	ImagePrefix string `yaml:"image_prefix" env:"IMAGE_PREFIX" default:""`

	// Default registry for pulling images
	DefaultRegistry string `yaml:"default_registry" env:"DEFAULT_REGISTRY" default:"docker.io"`
}

// LoadConfig loads configuration from environment variables and optional YAML file
// This is the canonical way to load configuration
func LoadConfig(configPath string) (*Config, error) {
	cfg := &Config{
		Domain:      getEnv("DOMAIN", "example.com"),
		StackName:   getEnv("STACK_NAME", "infra"),
		NodeName:    getEnv("TS_HOSTNAME", ""),
		ConfigPath:  getEnv("CONFIG_PATH", "./volumes"),
		SecretsPath: getEnv("SECRETS_PATH", "./secrets"),
		RootPath:    getEnv("ROOT_PATH", "."),
		DataDir:     getEnv("DATA_DIR", "/opt/constellation/data"),
		Networks:    make(map[string]NetworkConfig),
		Services:    []ServiceConfig{},
		Traefik: TraefikConfig{
			WebPort:              getEnvInt("TRAEFIK_WEB_PORT", 80),
			WebSecurePort:        getEnvInt("TRAEFIK_WEBSECURE_PORT", 443),
			ErrorPagesMiddleware: getEnv("TRAEFIK_ERROR_PAGES_MIDDLEWARE", "error-pages@file"),
			CrowdsecMiddleware:   getEnv("TRAEFIK_CROWDSEC_MIDDLEWARE", "crowdsec@file"),
			StripWWWMiddleware:   getEnv("TRAEFIK_STRIP_WWW_MIDDLEWARE", "strip-www@file"),
			CertResolver:         getEnv("TRAEFIK_CERT_RESOLVER", "letsencrypt"),
			HTTPProviderPort:     getEnvInt("TRAEFIK_HTTP_PROVIDER_PORT", 8081),
			CloudflareTrustedIPs: getCloudflareTrustedIPs(),
		},
		DNS: DNSConfig{
			Provider: getEnv("DNS_PROVIDER", "cloudflare"),
			APIKey:   getEnv("CLOUDFLARE_API_KEY", ""),
			APIEmail: getEnv("CLOUDFLARE_API_EMAIL", ""),
			ZoneID:   getEnv("CLOUDFLARE_ZONE_ID", ""),
		},
		Cluster: ClusterConfig{
			BindPort: getEnvInt("BIND_PORT", 7946),
			RaftPort: getEnvInt("RAFT_PORT", 8300),
			APIPort:  getEnvInt("API_PORT", 8080),
			Priority: getEnvInt("NODE_PRIORITY", 100),
		},
		Middlewares: MiddlewareConfig{
			ErrorPagesEnabled: true,
			ErrorPagesName:    "error-pages",
			CrowdsecEnabled:   true,
			CrowdsecName:      "crowdsec",
			StripWWWEnabled:   true,
			StripWWWName:      "strip-www",
		},
		Registry: RegistryConfig{
			ImagePrefix:     getEnv("IMAGE_PREFIX", ""),
			DefaultRegistry: getEnv("DEFAULT_REGISTRY", "docker.io"),
		},
	}

	// DNS domain inherits from top-level domain if not set
	if cfg.DNS.Domain == "" {
		cfg.DNS.Domain = cfg.Domain
	}

	// Load from YAML file if provided
	if configPath != "" {
		if err := cfg.LoadFromYAML(configPath); err != nil {
			return nil, fmt.Errorf("failed to load config from YAML: %w", err)
		}
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	return cfg, nil
}

// LoadFromYAML loads configuration from a YAML file
// This merges YAML values into the existing config (YAML takes precedence over defaults)
func (c *Config) LoadFromYAML(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read config file: %w", err)
	}

	// Create a temporary config to unmarshal into
	var yamlConfig Config
	if err := yaml.Unmarshal(data, &yamlConfig); err != nil {
		return fmt.Errorf("failed to parse YAML: %w", err)
	}

	// Merge YAML config into existing config (YAML values take precedence)
	if yamlConfig.Domain != "" {
		c.Domain = yamlConfig.Domain
	}
	if yamlConfig.StackName != "" {
		c.StackName = yamlConfig.StackName
	}
	if yamlConfig.NodeName != "" {
		c.NodeName = yamlConfig.NodeName
	}
	if yamlConfig.ConfigPath != "" {
		c.ConfigPath = yamlConfig.ConfigPath
	}
	if yamlConfig.SecretsPath != "" {
		c.SecretsPath = yamlConfig.SecretsPath
	}
	if yamlConfig.RootPath != "" {
		c.RootPath = yamlConfig.RootPath
	}
	if yamlConfig.DataDir != "" {
		c.DataDir = yamlConfig.DataDir
	}

	// Merge Traefik config
	if yamlConfig.Traefik.WebPort != 0 {
		c.Traefik.WebPort = yamlConfig.Traefik.WebPort
	}
	if yamlConfig.Traefik.WebSecurePort != 0 {
		c.Traefik.WebSecurePort = yamlConfig.Traefik.WebSecurePort
	}
	if yamlConfig.Traefik.ErrorPagesMiddleware != "" {
		c.Traefik.ErrorPagesMiddleware = yamlConfig.Traefik.ErrorPagesMiddleware
	}
	if yamlConfig.Traefik.CrowdsecMiddleware != "" {
		c.Traefik.CrowdsecMiddleware = yamlConfig.Traefik.CrowdsecMiddleware
	}
	if yamlConfig.Traefik.StripWWWMiddleware != "" {
		c.Traefik.StripWWWMiddleware = yamlConfig.Traefik.StripWWWMiddleware
	}
	if yamlConfig.Traefik.CertResolver != "" {
		c.Traefik.CertResolver = yamlConfig.Traefik.CertResolver
	}
	if yamlConfig.Traefik.HTTPProviderPort != 0 {
		c.Traefik.HTTPProviderPort = yamlConfig.Traefik.HTTPProviderPort
	}
	if len(yamlConfig.Traefik.CloudflareTrustedIPs) > 0 {
		c.Traefik.CloudflareTrustedIPs = yamlConfig.Traefik.CloudflareTrustedIPs
	}

	// Merge DNS config
	if yamlConfig.DNS.Provider != "" {
		c.DNS.Provider = yamlConfig.DNS.Provider
	}
	if yamlConfig.DNS.Domain != "" {
		c.DNS.Domain = yamlConfig.DNS.Domain
	}
	if yamlConfig.DNS.APIKey != "" {
		c.DNS.APIKey = yamlConfig.DNS.APIKey
	}
	if yamlConfig.DNS.APIEmail != "" {
		c.DNS.APIEmail = yamlConfig.DNS.APIEmail
	}
	if yamlConfig.DNS.ZoneID != "" {
		c.DNS.ZoneID = yamlConfig.DNS.ZoneID
	}

	// Merge Cluster config
	if yamlConfig.Cluster.BindPort != 0 {
		c.Cluster.BindPort = yamlConfig.Cluster.BindPort
	}
	if yamlConfig.Cluster.RaftPort != 0 {
		c.Cluster.RaftPort = yamlConfig.Cluster.RaftPort
	}
	if yamlConfig.Cluster.APIPort != 0 {
		c.Cluster.APIPort = yamlConfig.Cluster.APIPort
	}
	if yamlConfig.Cluster.Priority != 0 {
		c.Cluster.Priority = yamlConfig.Cluster.Priority
	}
	if yamlConfig.Cluster.BindAddr != "" {
		c.Cluster.BindAddr = yamlConfig.Cluster.BindAddr
	}
	if yamlConfig.Cluster.PublicIP != "" {
		c.Cluster.PublicIP = yamlConfig.Cluster.PublicIP
	}
	if yamlConfig.Cluster.TailscaleIP != "" {
		c.Cluster.TailscaleIP = yamlConfig.Cluster.TailscaleIP
	}

	// Merge Middleware config
	c.Middlewares.ErrorPagesEnabled = yamlConfig.Middlewares.ErrorPagesEnabled || c.Middlewares.ErrorPagesEnabled
	if yamlConfig.Middlewares.ErrorPagesName != "" {
		c.Middlewares.ErrorPagesName = yamlConfig.Middlewares.ErrorPagesName
	}
	c.Middlewares.CrowdsecEnabled = yamlConfig.Middlewares.CrowdsecEnabled || c.Middlewares.CrowdsecEnabled
	if yamlConfig.Middlewares.CrowdsecName != "" {
		c.Middlewares.CrowdsecName = yamlConfig.Middlewares.CrowdsecName
	}
	c.Middlewares.StripWWWEnabled = yamlConfig.Middlewares.StripWWWEnabled || c.Middlewares.StripWWWEnabled
	if yamlConfig.Middlewares.StripWWWName != "" {
		c.Middlewares.StripWWWName = yamlConfig.Middlewares.StripWWWName
	}

	// Merge Registry config
	if yamlConfig.Registry.ImagePrefix != "" {
		c.Registry.ImagePrefix = yamlConfig.Registry.ImagePrefix
	}
	if yamlConfig.Registry.DefaultRegistry != "" {
		c.Registry.DefaultRegistry = yamlConfig.Registry.DefaultRegistry
	}

	// Merge Networks (replace entire map)
	if len(yamlConfig.Networks) > 0 {
		if c.Networks == nil {
			c.Networks = make(map[string]NetworkConfig)
		}
		for k, v := range yamlConfig.Networks {
			c.Networks[k] = v
		}
	}

	// Merge Services (append)
	if len(yamlConfig.Services) > 0 {
		c.Services = append(c.Services, yamlConfig.Services...)
	}

	// DNS domain inherits from top-level domain if not set
	if c.DNS.Domain == "" {
		c.DNS.Domain = c.Domain
	}

	return nil
}

// Validate validates the configuration
func (c *Config) Validate() error {
	var errors []string

	// Validate domain
	if c.Domain == "" {
		errors = append(errors, "domain is required")
	} else if !isValidDomain(c.Domain) {
		errors = append(errors, fmt.Sprintf("domain '%s' is not a valid domain name", c.Domain))
	}

	// Validate stack name
	if c.StackName == "" {
		errors = append(errors, "stack_name is required")
	} else if !isValidStackName(c.StackName) {
		errors = append(errors, fmt.Sprintf("stack_name '%s' contains invalid characters (must be alphanumeric, hyphens, or underscores)", c.StackName))
	}

	// Validate ports
	if c.Traefik.WebPort < 1 || c.Traefik.WebPort > 65535 {
		errors = append(errors, fmt.Sprintf("traefik.web_port must be between 1 and 65535, got %d", c.Traefik.WebPort))
	}
	if c.Traefik.WebSecurePort < 1 || c.Traefik.WebSecurePort > 65535 {
		errors = append(errors, fmt.Sprintf("traefik.websecure_port must be between 1 and 65535, got %d", c.Traefik.WebSecurePort))
	}
	if c.Traefik.HTTPProviderPort < 1 || c.Traefik.HTTPProviderPort > 65535 {
		errors = append(errors, fmt.Sprintf("traefik.http_provider_port must be between 1 and 65535, got %d", c.Traefik.HTTPProviderPort))
	}
	if c.Cluster.BindPort < 1 || c.Cluster.BindPort > 65535 {
		errors = append(errors, fmt.Sprintf("cluster.bind_port must be between 1 and 65535, got %d", c.Cluster.BindPort))
	}
	if c.Cluster.RaftPort < 1 || c.Cluster.RaftPort > 65535 {
		errors = append(errors, fmt.Sprintf("cluster.raft_port must be between 1 and 65535, got %d", c.Cluster.RaftPort))
	}
	if c.Cluster.APIPort < 1 || c.Cluster.APIPort > 65535 {
		errors = append(errors, fmt.Sprintf("cluster.api_port must be between 1 and 65535, got %d", c.Cluster.APIPort))
	}

	// Validate port uniqueness
	ports := map[int]string{
		c.Traefik.WebPort:          "traefik.web_port",
		c.Traefik.WebSecurePort:    "traefik.websecure_port",
		c.Traefik.HTTPProviderPort: "traefik.http_provider_port",
		c.Cluster.BindPort:         "cluster.bind_port",
		c.Cluster.RaftPort:         "cluster.raft_port",
		c.Cluster.APIPort:          "cluster.api_port",
	}
	portUsage := make(map[int][]string)
	for port, name := range ports {
		if port > 0 {
			portUsage[port] = append(portUsage[port], name)
		}
	}
	for port, names := range portUsage {
		if len(names) > 1 {
			errors = append(errors, fmt.Sprintf("port %d is used by multiple services: %s", port, strings.Join(names, ", ")))
		}
	}

	// Validate paths
	if c.ConfigPath == "" {
		errors = append(errors, "config_path is required")
	}
	if c.SecretsPath == "" {
		errors = append(errors, "secrets_path is required")
	}
	if c.DataDir == "" {
		errors = append(errors, "data_dir is required")
	}

	// Validate DNS provider
	if c.DNS.Provider != "" && c.DNS.Provider != "cloudflare" && c.DNS.Provider != "route53" {
		errors = append(errors, fmt.Sprintf("dns.provider '%s' is not supported (supported: cloudflare, route53)", c.DNS.Provider))
	}

	// Validate Cloudflare trusted IPs
	for _, ip := range c.Traefik.CloudflareTrustedIPs {
		if _, _, err := net.ParseCIDR(ip); err != nil {
			errors = append(errors, fmt.Sprintf("invalid Cloudflare trusted IP CIDR: %s", ip))
		}
	}

	// Validate registry
	if c.Registry.DefaultRegistry != "" && !isValidRegistry(c.Registry.DefaultRegistry) {
		errors = append(errors, fmt.Sprintf("registry.default_registry '%s' is not a valid registry", c.Registry.DefaultRegistry))
	}

	// Resolve relative paths
	if !filepath.IsAbs(c.ConfigPath) && c.RootPath != "." {
		c.ConfigPath = filepath.Join(c.RootPath, c.ConfigPath)
	}
	if !filepath.IsAbs(c.SecretsPath) && c.RootPath != "." {
		c.SecretsPath = filepath.Join(c.RootPath, c.SecretsPath)
	}

	if len(errors) > 0 {
		return fmt.Errorf("validation errors: %s", strings.Join(errors, "; "))
	}

	return nil
}

// Helper validation functions
func isValidDomain(domain string) bool {
	if len(domain) == 0 || len(domain) > 253 {
		return false
	}
	// Basic domain validation - must contain at least one dot and valid characters
	if !strings.Contains(domain, ".") {
		return false
	}
	// Check for valid characters (alphanumeric, dots, hyphens)
	for _, r := range domain {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '.' || r == '-') {
			return false
		}
	}
	return true
}

func isValidStackName(name string) bool {
	if len(name) == 0 {
		return false
	}
	// Stack name must be alphanumeric, hyphens, or underscores
	for _, r := range name {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_') {
			return false
		}
	}
	return true
}

func isValidRegistry(registry string) bool {
	if len(registry) == 0 {
		return false
	}
	// Basic registry validation - must be a valid hostname or docker.io
	if registry == "docker.io" || registry == "docker.com" {
		return true
	}
	// Check if it's a valid hostname
	return isValidDomain(registry) || strings.HasPrefix(registry, "localhost")
}

// GetFullNetworkName returns the full network name with stack prefix
func (c *Config) GetFullNetworkName(netName string) string {
	if c.StackName == "" {
		return netName
	}
	if netName == "default" {
		return c.StackName + "_default"
	}
	return c.StackName + "_" + netName
}

// GetImageName returns the full image name with registry prefix if configured
func (c *Config) GetImageName(image string) string {
	if c.Registry.ImagePrefix == "" {
		return image
	}
	// If image already has a registry, don't add prefix
	if strings.Contains(image, "/") && !strings.HasPrefix(image, c.Registry.ImagePrefix) {
		parts := strings.Split(image, "/")
		if len(parts) > 1 {
			// Image already has registry
			return image
		}
	}
	return c.Registry.ImagePrefix + "/" + image
}

// GetTraefikMiddlewares returns the configured middleware string for Traefik
func (c *Config) GetTraefikMiddlewares() string {
	middlewares := []string{}

	if c.Middlewares.ErrorPagesEnabled {
		middlewares = append(middlewares, c.Traefik.ErrorPagesMiddleware)
	}
	if c.Middlewares.CrowdsecEnabled {
		middlewares = append(middlewares, c.Traefik.CrowdsecMiddleware)
	}
	if c.Middlewares.StripWWWEnabled {
		middlewares = append(middlewares, c.Traefik.StripWWWMiddleware)
	}

	return strings.Join(middlewares, ",")
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	val := os.Getenv(key)
	if val == "" {
		return defaultValue
	}
	var result int
	if _, err := fmt.Sscanf(val, "%d", &result); err != nil {
		return defaultValue
	}
	return result
}

func getCloudflareTrustedIPs() []string {
	// Default Cloudflare IP ranges
	return []string{
		"103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22",
		"104.16.0.0/13", "104.24.0.0/14", "108.162.192.0/18",
		"131.0.72.0/22", "141.101.64.0/18", "162.158.0.0/15",
		"172.64.0.0/13", "173.245.48.0/20", "188.114.96.0/20",
		"190.93.240.0/20", "197.234.240.0/22", "198.41.128.0/17",
		"2400:cb00::/32", "2405:8100::/32", "2405:b500::/32",
		"2606:4700::/32", "2803:f800::/32", "2a06:98c0::/29",
		"2c0f:f248::/32",
	}
}
