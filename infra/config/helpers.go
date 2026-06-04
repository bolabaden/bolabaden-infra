package config

import (
	"fmt"
	"net/url"
	"strings"
)

// BuildServiceURL builds a complete service URL
func BuildServiceURL(cfg *Config, serviceName string, useHTTPS bool, path string) string {
	scheme := "http"
	if useHTTPS {
		scheme = "https"
	}

	host := BuildFQDN(serviceName, cfg.NodeName, cfg.Domain)

	if path != "" {
		if !strings.HasPrefix(path, "/") {
			path = "/" + path
		}
		return fmt.Sprintf("%s://%s%s", scheme, host, path)
	}
	return fmt.Sprintf("%s://%s", scheme, host)
}

// BuildInternalServiceURL builds a URL for internal service communication
// Uses service name directly (no domain) for Docker network communication
func BuildInternalServiceURL(serviceName string, port int, path string) string {
	host := serviceName
	if port > 0 && port != 80 && port != 443 {
		host = fmt.Sprintf("%s:%d", serviceName, port)
	}

	if path != "" {
		if !strings.HasPrefix(path, "/") {
			path = "/" + path
		}
		return fmt.Sprintf("http://%s%s", host, path)
	}
	return fmt.Sprintf("http://%s", host)
}

// ValidateURL validates a URL string
func ValidateURL(urlStr string) error {
	_, err := url.Parse(urlStr)
	return err
}

// BuildNetworkName builds a full network name with stack prefix
func BuildNetworkName(cfg *Config, networkName string) string {
	return cfg.GetFullNetworkName(networkName)
}

// BuildVolumePath builds a volume path, resolving relative paths
func BuildVolumePath(cfg *Config, volumePath string) string {
	if strings.HasPrefix(volumePath, "/") {
		return volumePath // Absolute path
	}
	return fmt.Sprintf("%s/%s", cfg.ConfigPath, strings.TrimPrefix(volumePath, "./"))
}

// BuildSecretPath builds a secret file path
func BuildSecretPath(cfg *Config, secretName string) string {
	return fmt.Sprintf("%s/%s", cfg.SecretsPath, secretName)
}

// BuildConfigFilePath builds a config file path
func BuildConfigFilePath(cfg *Config, configName string) string {
	return fmt.Sprintf("%s/%s", cfg.ConfigPath, configName)
}

// IsProduction checks if configuration appears to be for production
func IsProduction(cfg *Config) bool {
	// Heuristic: production typically has:
	// - Non-localhost domain
	// - Absolute paths
	// - Image prefix set
	return cfg.Domain != "localhost" &&
		cfg.Domain != "127.0.0.1" &&
		!strings.Contains(cfg.Domain, "local") &&
		strings.HasPrefix(cfg.ConfigPath, "/") &&
		cfg.Registry.ImagePrefix != ""
}

// IsDevelopment checks if configuration appears to be for development
func IsDevelopment(cfg *Config) bool {
	return cfg.Domain == "localhost" ||
		strings.Contains(cfg.Domain, "local") ||
		!strings.HasPrefix(cfg.ConfigPath, "/") ||
		cfg.StackName == "dev" ||
		cfg.StackName == "development"
}

// GetEffectiveDomain returns the effective domain (with node prefix if node name is set)
func GetEffectiveDomain(cfg *Config, serviceName string) string {
	return BuildFQDN(serviceName, cfg.NodeName, cfg.Domain)
}

// GetServicePort returns the port for a service from Traefik labels or default
func GetServicePort(labels map[string]string, defaultPort string) string {
	// Try to find port in Traefik labels
	for key, value := range labels {
		if strings.Contains(key, "loadbalancer.server.port") {
			return value
		}
	}
	return defaultPort
}

// BuildEnvironmentMap builds an environment variable map with common defaults
func BuildEnvironmentMap(cfg *Config, serviceDefaults map[string]string, overrides map[string]string) map[string]string {
	env := make(map[string]string)

	// Add common infrastructure variables
	env["DOMAIN"] = cfg.Domain
	env["STACK_NAME"] = cfg.StackName
	if cfg.NodeName != "" {
		env["NODE_NAME"] = cfg.NodeName
		env["TS_HOSTNAME"] = cfg.NodeName
	}

	// Add service defaults
	for k, v := range serviceDefaults {
		env[k] = v
	}

	// Add overrides (highest priority)
	for k, v := range overrides {
		env[k] = v
	}

	return env
}

// SanitizeStackName sanitizes a stack name to be valid
func SanitizeStackName(name string) string {
	// Remove invalid characters, keep alphanumeric, hyphens, underscores
	var result strings.Builder
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			result.WriteRune(r)
		}
	}
	sanitized := result.String()
	if sanitized == "" {
		return "infra"
	}
	return sanitized
}

// SanitizeDomain sanitizes a domain name
func SanitizeDomain(domain string) string {
	// Remove invalid characters, keep alphanumeric, dots, hyphens
	var result strings.Builder
	for _, r := range domain {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '.' || r == '-' {
			result.WriteRune(r)
		}
	}
	return result.String()
}

// MergeConfigs merges two configurations, with cfg2 taking precedence
func MergeConfigs(cfg1, cfg2 *Config) *Config {
	result := *cfg1 // Copy cfg1

	// Merge fields where cfg2 has non-zero values
	if cfg2.Domain != "" {
		result.Domain = cfg2.Domain
	}
	if cfg2.StackName != "" {
		result.StackName = cfg2.StackName
	}
	if cfg2.NodeName != "" {
		result.NodeName = cfg2.NodeName
	}
	if cfg2.ConfigPath != "" {
		result.ConfigPath = cfg2.ConfigPath
	}
	if cfg2.SecretsPath != "" {
		result.SecretsPath = cfg2.SecretsPath
	}
	if cfg2.DataDir != "" {
		result.DataDir = cfg2.DataDir
	}

	// Merge nested configs (simplified - in production, use reflection or deep merge)
	if cfg2.Traefik.WebPort != 0 {
		result.Traefik.WebPort = cfg2.Traefik.WebPort
	}
	if cfg2.Traefik.WebSecurePort != 0 {
		result.Traefik.WebSecurePort = cfg2.Traefik.WebSecurePort
	}
	if cfg2.Cluster.BindPort != 0 {
		result.Cluster.BindPort = cfg2.Cluster.BindPort
	}

	return &result
}

// GetConfigSummary returns a human-readable summary of the configuration
func GetConfigSummary(cfg *Config) string {
	var summary strings.Builder

	summary.WriteString("Configuration Summary\n")
	summary.WriteString("====================\n")
	summary.WriteString(fmt.Sprintf("Domain:        %s\n", cfg.Domain))
	summary.WriteString(fmt.Sprintf("Stack Name:    %s\n", cfg.StackName))
	summary.WriteString(fmt.Sprintf("Node Name:     %s\n", cfg.NodeName))
	summary.WriteString(fmt.Sprintf("Environment:   %s\n", getEnvironment(cfg)))
	summary.WriteString(fmt.Sprintf("Config Path:   %s\n", cfg.ConfigPath))
	summary.WriteString(fmt.Sprintf("Secrets Path:  %s\n", cfg.SecretsPath))
	summary.WriteString(fmt.Sprintf("Data Dir:      %s\n", cfg.DataDir))

	return summary.String()
}

func getEnvironment(cfg *Config) string {
	if IsProduction(cfg) {
		return "production"
	}
	if IsDevelopment(cfg) {
		return "development"
	}
	return "unknown"
}
