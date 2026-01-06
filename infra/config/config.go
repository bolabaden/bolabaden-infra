package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
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
func (c *Config) LoadFromYAML(path string) error {
	// This would use gopkg.in/yaml.v3 to load the file
	// For now, we'll implement a basic version
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read config file: %w", err)
	}

	// Parse YAML (simplified - in real implementation, use yaml.v3)
	// For now, we'll just validate the file exists and is readable
	_ = data

	return nil
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.Domain == "" {
		return fmt.Errorf("domain is required")
	}

	if c.StackName == "" {
		return fmt.Errorf("stack_name is required")
	}

	// Resolve relative paths
	if !filepath.IsAbs(c.ConfigPath) && c.RootPath != "." {
		c.ConfigPath = filepath.Join(c.RootPath, c.ConfigPath)
	}
	if !filepath.IsAbs(c.SecretsPath) && c.RootPath != "." {
		c.SecretsPath = filepath.Join(c.RootPath, c.SecretsPath)
	}

	return nil
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
