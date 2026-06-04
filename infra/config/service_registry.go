package config

import (
	"fmt"
	"strings"
)

// ServiceRegistry allows registration and discovery of service definitions
// This enables a plugin-like architecture where services can be defined
// externally or programmatically
type ServiceRegistry struct {
	services map[string]ServiceProvider
}

// ServiceProvider is an interface for providing service definitions
// This allows for different sources: built-in, YAML files, plugins, etc.
type ServiceProvider interface {
	// GetServices returns service definitions for the given configuration
	GetServices(cfg *Config) ([]ServiceConfig, error)
	
	// Name returns the name of this provider
	Name() string
}

// NewServiceRegistry creates a new service registry
func NewServiceRegistry() *ServiceRegistry {
	return &ServiceRegistry{
		services: make(map[string]ServiceProvider),
	}
}

// Register registers a service provider
func (sr *ServiceRegistry) Register(provider ServiceProvider) error {
	name := provider.Name()
	if _, exists := sr.services[name]; exists {
		return fmt.Errorf("service provider %s already registered", name)
	}
	sr.services[name] = provider
	return nil
}

// GetServices collects all services from all registered providers
func (sr *ServiceRegistry) GetServices(cfg *Config) ([]ServiceConfig, error) {
	allServices := []ServiceConfig{}
	
	for name, provider := range sr.services {
		services, err := provider.GetServices(cfg)
		if err != nil {
			return nil, fmt.Errorf("provider %s failed: %w", name, err)
		}
		allServices = append(allServices, services...)
	}
	
	return allServices, nil
}

// BuiltInServiceProvider provides built-in service definitions
// This can be extended or replaced by users
type BuiltInServiceProvider struct {
	serviceDefiners []ServiceDefiner
}

// ServiceDefiner is a function that defines services
// This allows for modular service definition
type ServiceDefiner func(cfg *Config) []ServiceConfig

// NewBuiltInServiceProvider creates a built-in service provider
func NewBuiltInServiceProvider(definers ...ServiceDefiner) *BuiltInServiceProvider {
	return &BuiltInServiceProvider{
		serviceDefiners: definers,
	}
}

// Name returns the provider name
func (b *BuiltInServiceProvider) Name() string {
	return "builtin"
}

// GetServices collects services from all definers
func (b *BuiltInServiceProvider) GetServices(cfg *Config) ([]ServiceConfig, error) {
	allServices := []ServiceConfig{}
	
	for _, definer := range b.serviceDefiners {
		services := definer(cfg)
		allServices = append(allServices, services...)
	}
	
	return allServices, nil
}

// AddDefiner adds a service definer
func (b *BuiltInServiceProvider) AddDefiner(definer ServiceDefiner) {
	b.serviceDefiners = append(b.serviceDefiners, definer)
}

// YAMLServiceProvider loads services from YAML files
type YAMLServiceProvider struct {
	filePath string
}

// NewYAMLServiceProvider creates a YAML service provider
func NewYAMLServiceProvider(filePath string) *YAMLServiceProvider {
	return &YAMLServiceProvider{
		filePath: filePath,
	}
}

// Name returns the provider name
func (y *YAMLServiceProvider) Name() string {
	return fmt.Sprintf("yaml:%s", y.filePath)
}

// GetServices loads services from YAML file
func (y *YAMLServiceProvider) GetServices(cfg *Config) ([]ServiceConfig, error) {
	// This would load from YAML file
	// For now, return empty - implement with yaml.v3
	return []ServiceConfig{}, nil
}

// Helper function to build FQDN
func BuildFQDN(serviceName, nodeName, domain string) string {
	if nodeName != "" {
		return fmt.Sprintf("%s.%s.%s", serviceName, nodeName, domain)
	}
	return fmt.Sprintf("%s.%s", serviceName, domain)
}

// Helper function to build URL
func BuildURL(serviceName, domain string, useHTTPS bool) string {
	scheme := "http"
	if useHTTPS {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s.%s", scheme, serviceName, domain)
}

// Helper function to resolve image name with registry prefix
func ResolveImageName(cfg *Config, image string) string {
	return cfg.GetImageName(image)
}

// Helper function to build environment variable map with defaults
func BuildEnvMap(cfg *Config, defaults map[string]string, overrides map[string]string) map[string]string {
	env := make(map[string]string)
	
	// Start with defaults
	for k, v := range defaults {
		env[k] = v
	}
	
	// Apply config-based values
	env["DOMAIN"] = cfg.Domain
	env["STACK_NAME"] = cfg.StackName
	
	// Apply overrides (highest priority)
	for k, v := range overrides {
		env[k] = v
	}
	
	return env
}

// Helper function to build Traefik labels
func BuildTraefikLabels(cfg *Config, serviceName string, options TraefikLabelOptions) map[string]string {
	labels := make(map[string]string)
	
	// Base Traefik labels
	labels["traefik.enable"] = "true"
	
	// Router labels
	routerName := serviceName
	if options.RouterName != "" {
		routerName = options.RouterName
	}
	
	// Rule
	rule := fmt.Sprintf("Host(`%s.%s`)", serviceName, cfg.Domain)
	if options.Rule != "" {
		rule = options.Rule
	}
	labels[fmt.Sprintf("traefik.http.routers.%s.rule", routerName)] = rule
	
	// Entry point
	entryPoint := "websecure"
	if options.EntryPoint != "" {
		entryPoint = options.EntryPoint
	}
	labels[fmt.Sprintf("traefik.http.routers.%s.entrypoints", routerName)] = entryPoint
	
	// TLS
	if options.TLS {
		labels[fmt.Sprintf("traefik.http.routers.%s.tls", routerName)] = "true"
		labels[fmt.Sprintf("traefik.http.routers.%s.tls.certresolver", routerName)] = cfg.Traefik.CertResolver
	}
	
	// Service
	serviceNameLabel := serviceName
	if options.ServiceName != "" {
		serviceNameLabel = options.ServiceName
	}
	labels[fmt.Sprintf("traefik.http.routers.%s.service", routerName)] = serviceNameLabel
	
	// Middlewares
	if len(options.Middlewares) > 0 {
		middlewares := strings.Join(options.Middlewares, ",")
		labels[fmt.Sprintf("traefik.http.routers.%s.middlewares", routerName)] = middlewares
	} else if cfg.Middlewares.ErrorPagesEnabled || cfg.Middlewares.CrowdsecEnabled || cfg.Middlewares.StripWWWEnabled {
		labels[fmt.Sprintf("traefik.http.routers.%s.middlewares", routerName)] = cfg.GetTraefikMiddlewares()
	}
	
	// Port
	if options.Port != "" {
		labels[fmt.Sprintf("traefik.http.services.%s.loadbalancer.server.port", serviceNameLabel)] = options.Port
	}
	
	return labels
}

// TraefikLabelOptions configures Traefik label generation
type TraefikLabelOptions struct {
	RouterName string
	Rule       string
	EntryPoint string
	ServiceName string
	TLS        bool
	Middlewares []string
	Port       string
}

