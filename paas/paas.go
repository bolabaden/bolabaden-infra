package paas

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

// PaaS represents the Platform as a Service system
type PaaS struct {
	// Configuration
	config *PaaSConfig
}

// PaaSConfig holds PaaS configuration
type PaaSConfig struct {
	// Default platform for conversions
	DefaultPlatform Platform

	// Working directory for temporary files
	WorkDir string

	// Whether to preserve extensions during conversion
	PreserveExtensions bool
}

// New creates a new PaaS instance
func New(config *PaaSConfig) *PaaS {
	if config == nil {
		config = &PaaSConfig{
			DefaultPlatform:    PlatformDockerCompose,
			WorkDir:            "/tmp/paas",
			PreserveExtensions: true,
		}
	}

	if config.WorkDir == "" {
		config.WorkDir = "/tmp/paas"
	}

	// Create working directory
	os.MkdirAll(config.WorkDir, 0755)

	return &PaaS{
		config: config,
	}
}

// LoadFile loads an application from a file
func (p *PaaS) LoadFile(filename string) (*Application, error) {
	// Check if it's a Helm chart directory
	if info, err := os.Stat(filename); err == nil && info.IsDir() {
		chartYaml := filepath.Join(filename, "Chart.yaml")
		if _, err := os.Stat(chartYaml); err == nil {
			return ParseHelmChart(filename)
		}
	}

	content, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read file %s: %w", filename, err)
	}

	return p.LoadContent(string(content), p.detectPlatform(filename))
}

// LoadContent loads an application from content string
func (p *PaaS) LoadContent(content string, platform Platform) (*Application, error) {
	switch platform {
	case PlatformDockerCompose:
		return ParseDockerCompose(content)
	case PlatformNomad:
		return ParseNomadHCL(content)
	case PlatformKubernetes:
		return ParseKubernetesYAML(content)
	case PlatformHelm:
		// For Helm, we need a directory, not content
		return nil, fmt.Errorf("Helm charts must be loaded from directories, not content strings")
	default:
		return nil, fmt.Errorf("unsupported platform: %s", platform)
	}
}

// SaveFile saves an application to a file
func (p *PaaS) SaveFile(app *Application, filename string) error {
	platform := p.detectPlatform(filename)

	// Special handling for Helm charts
	if platform == PlatformHelm {
		return SerializeHelmChart(app, filename)
	}

	content, err := p.SaveContent(app, platform)
	if err != nil {
		return err
	}

	return ioutil.WriteFile(filename, []byte(content), 0644)
}

// SaveContent saves an application to a content string
func (p *PaaS) SaveContent(app *Application, platform Platform) (string, error) {
	switch platform {
	case PlatformDockerCompose:
		return SerializeDockerCompose(app)
	case PlatformNomad:
		return SerializeNomadHCL(app)
	case PlatformKubernetes:
		return SerializeKubernetesYAML(app)
	case PlatformHelm:
		return "", fmt.Errorf("Helm charts must be saved to directories, not content strings")
	default:
		return "", fmt.Errorf("unsupported platform: %s", platform)
	}
}

// Convert converts an application from one platform to another
func (p *PaaS) Convert(app *Application, from, to Platform) (*Application, error) {
	// If already in target format, return as-is
	if app.Platform == to {
		return app, nil
	}

	// For now, create a new application with the target platform
	converted := &Application{
		Version:     app.Version,
		Platform:    to,
		Services:    make(map[string]*Service),
		Networks:    make(map[string]*Network),
		Volumes:     make(map[string]*Volume),
		Configs:     make(map[string]*Config),
		Secrets:     make(map[string]*Secret),
		Includes:    app.Includes,
		Extensions:  app.Extensions,
		SourceFiles: app.SourceFiles,
	}

	// Deep copy services with platform conversion
	for name, service := range app.Services {
		convertedService := *service // Shallow copy
		convertedService.Platform = to

		// Convert platform-specific attributes
		if err := p.convertServiceAttributes(&convertedService, from, to); err != nil {
			return nil, fmt.Errorf("failed to convert service %s: %w", name, err)
		}

		converted.Services[name] = &convertedService
	}

	// Copy other resources (networks, volumes, etc.)
	for name, network := range app.Networks {
		convertedNetwork := *network
		converted.Networks[name] = &convertedNetwork
	}

	for name, volume := range app.Volumes {
		convertedVolume := *volume
		converted.Volumes[name] = &convertedVolume
	}

	for name, config := range app.Configs {
		convertedConfig := *config
		converted.Configs[name] = &convertedConfig
	}

	for name, secret := range app.Secrets {
		convertedSecret := *secret
		converted.Secrets[name] = &convertedSecret
	}

	return converted, nil
}

// convertServiceAttributes converts platform-specific service attributes
func (p *PaaS) convertServiceAttributes(service *Service, from, to Platform) error {
	// Handle platform-specific conversions
	switch from {
	case PlatformDockerCompose:
		switch to {
		case PlatformNomad:
			return p.convertDockerToNomad(service)
		case PlatformKubernetes:
			return p.convertDockerToKubernetes(service)
		}
	case PlatformNomad:
		switch to {
		case PlatformDockerCompose:
			return p.convertNomadToDocker(service)
		case PlatformKubernetes:
			return p.convertNomadToKubernetes(service)
		}
	case PlatformKubernetes:
		switch to {
		case PlatformDockerCompose:
			return p.convertKubernetesToDocker(service)
		case PlatformNomad:
			return p.convertKubernetesToNomad(service)
		}
	}

	return nil
}

// convertDockerToNomad converts Docker Compose service attributes to Nomad
func (p *PaaS) convertDockerToNomad(service *Service) error {
	// Convert restart policies
	switch service.Restart {
	case "always":
		service.Restart = "" // Nomad default is restart
	case "no":
		service.Restart = "no"
	case "unless-stopped":
		service.Restart = "" // Nomad handles this differently
	}

	// Convert labels to Nomad metadata
	if len(service.Labels) > 0 {
		if service.Extensions == nil {
			service.Extensions = make(map[string]interface{})
		}
		service.Extensions["labels"] = service.Labels
	}

	return nil
}

// convertDockerToKubernetes converts Docker Compose to Kubernetes
func (p *PaaS) convertDockerToKubernetes(service *Service) error {
	// Convert restart policies
	switch service.Restart {
	case "always":
		service.Restart = "Always"
	case "no":
		service.Restart = "Never"
	case "unless-stopped":
		service.Restart = "OnFailure"
	}

	return nil
}

// convertNomadToDocker converts Nomad service attributes to Docker Compose
func (p *PaaS) convertNomadToDocker(service *Service) error {
	// Nomad restart policies are different from Docker
	// Nomad handles restarts at the job level, not service level
	service.Restart = "unless-stopped" // Default Docker behavior

	return nil
}

// convertNomadToKubernetes converts Nomad to Kubernetes
func (p *PaaS) convertNomadToKubernetes(service *Service) error {
	// Similar to Docker conversion
	return p.convertNomadToDocker(service)
}

// convertKubernetesToDocker converts Kubernetes service attributes to Docker Compose
func (p *PaaS) convertKubernetesToDocker(service *Service) error {
	// Convert restart policies
	switch service.Restart {
	case "Always":
		service.Restart = "always"
	case "Never":
		service.Restart = "no"
	case "OnFailure":
		service.Restart = "unless-stopped"
	}

	return nil
}

// convertKubernetesToNomad converts Kubernetes to Nomad
func (p *PaaS) convertKubernetesToNomad(service *Service) error {
	// Similar to Docker conversion
	return p.convertKubernetesToDocker(service)
}

// detectPlatform detects the platform from filename extension
func (p *PaaS) detectPlatform(filename string) Platform {
	// Check if it's a directory (potential Helm chart)
	if info, err := os.Stat(filename); err == nil && info.IsDir() {
		chartYaml := filepath.Join(filename, "Chart.yaml")
		if _, err := os.Stat(chartYaml); err == nil {
			return PlatformHelm
		}
	}

	ext := strings.ToLower(filepath.Ext(filename))

	switch ext {
	case ".yml", ".yaml":
		// Check if it's Kubernetes or Docker Compose
		if strings.Contains(filename, "k8s") || strings.Contains(filename, "kubernetes") {
			return PlatformKubernetes
		}
		return PlatformDockerCompose
	case ".hcl", ".nomad":
		return PlatformNomad
	default:
		return p.config.DefaultPlatform
	}
}

// Validate validates an application
func (p *PaaS) Validate(app *Application) error {
	return app.Validate()
}

// RoundTrip performs a round-trip conversion test
func (p *PaaS) RoundTrip(app *Application, platforms ...Platform) error {
	original := app.Platform

	for _, targetPlatform := range platforms {
		converted, err := p.Convert(app, original, targetPlatform)
		if err != nil {
			return fmt.Errorf("failed to convert %s -> %s: %w", original, targetPlatform, err)
		}

		// Convert back
		backConverted, err := p.Convert(converted, targetPlatform, original)
		if err != nil {
			return fmt.Errorf("failed to convert back %s -> %s: %w", targetPlatform, original, err)
		}

		// Validate the round-trip
		if err := p.Validate(backConverted); err != nil {
			return fmt.Errorf("round-trip validation failed for %s: %w", targetPlatform, err)
		}

		// Basic structural comparison
		if len(backConverted.Services) != len(app.Services) {
			return fmt.Errorf("round-trip failed: service count mismatch for %s", targetPlatform)
		}
	}

	return nil
}

// ListServices returns a list of service names
func (p *PaaS) ListServices(app *Application) []string {
	var names []string
	for name := range app.Services {
		names = append(names, name)
	}
	return names
}

// GetService returns a service by name
func (p *PaaS) GetService(app *Application, name string) (*Service, bool) {
	service, exists := app.Services[name]
	return service, exists
}

// AddService adds a service to the application
func (p *PaaS) AddService(app *Application, service *Service) {
	app.Services[service.Name] = service
}

// RemoveService removes a service from the application
func (p *PaaS) RemoveService(app *Application, name string) {
	delete(app.Services, name)
}

// MergeApplications merges multiple applications
func (p *PaaS) MergeApplications(apps ...*Application) (*Application, error) {
	if len(apps) == 0 {
		return nil, fmt.Errorf("no applications to merge")
	}

	merged := &Application{
		Platform: apps[0].Platform,
		Services: make(map[string]*Service),
		Networks: make(map[string]*Network),
		Volumes:  make(map[string]*Volume),
		Configs:  make(map[string]*Config),
		Secrets:  make(map[string]*Secret),
	}

	for _, app := range apps {
		// Merge services
		for name, service := range app.Services {
			if _, exists := merged.Services[name]; exists {
				return nil, fmt.Errorf("service %s already exists", name)
			}
			merged.Services[name] = service
		}

		// Merge networks
		for name, network := range app.Networks {
			if _, exists := merged.Networks[name]; !exists {
				merged.Networks[name] = network
			}
		}

		// Merge volumes
		for name, volume := range app.Volumes {
			if _, exists := merged.Volumes[name]; !exists {
				merged.Volumes[name] = volume
			}
		}

		// Merge configs
		for name, config := range app.Configs {
			if _, exists := merged.Configs[name]; !exists {
				merged.Configs[name] = config
			}
		}

		// Merge secrets
		for name, secret := range app.Secrets {
			if _, exists := merged.Secrets[name]; !exists {
				merged.Secrets[name] = secret
			}
		}
	}

	return merged, nil
}
