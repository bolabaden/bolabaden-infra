package paas

import (
	"fmt"
	"strings"
)

// Platform represents the source platform of a service
type Platform string

const (
	PlatformDockerCompose Platform = "docker-compose"
	PlatformNomad         Platform = "nomad"
	PlatformKubernetes    Platform = "kubernetes"
	PlatformHelm          Platform = "helm"
)

// Service represents a containerized service that can be deployed
type Service struct {
	// Basic identification
	Name          string `json:"name" yaml:"name"`
	Image         string `json:"image" yaml:"image"`
	ContainerName string `json:"container_name,omitempty" yaml:"container_name,omitempty"`
	Hostname      string `json:"hostname,omitempty" yaml:"hostname,omitempty"`

	// Networking
	Ports    []PortMapping `json:"ports,omitempty" yaml:"ports,omitempty"`
	Networks []string      `json:"networks,omitempty" yaml:"networks,omitempty"`
	Expose   []string      `json:"expose,omitempty" yaml:"expose,omitempty"`

	// Environment and configuration
	Environment map[string]string `json:"environment,omitempty" yaml:"environment,omitempty"`
	EnvFile     []string          `json:"env_file,omitempty" yaml:"env_file,omitempty"`
	Command     []string          `json:"command,omitempty" yaml:"command,omitempty"`
	Entrypoint  []string          `json:"entrypoint,omitempty" yaml:"entrypoint,omitempty"`
	WorkingDir  string            `json:"working_dir,omitempty" yaml:"working_dir,omitempty"`

	// Volumes and mounts
	Volumes []VolumeMount `json:"volumes,omitempty" yaml:"volumes,omitempty"`

	// Dependencies and ordering
	DependsOn []string `json:"depends_on,omitempty" yaml:"depends_on,omitempty"`
	Links     []string `json:"links,omitempty" yaml:"links,omitempty"`

	// Runtime behavior
	Restart    string `json:"restart,omitempty" yaml:"restart,omitempty"`
	Privileged bool   `json:"privileged,omitempty" yaml:"privileged,omitempty"`
	User       string `json:"user,omitempty" yaml:"user,omitempty"`
	Group      string `json:"group,omitempty" yaml:"group,omitempty"`

	// Resource limits
	CPUShares   int    `json:"cpu_shares,omitempty" yaml:"cpu_shares,omitempty"`
	CPUQuota    int    `json:"cpu_quota,omitempty" yaml:"cpu_quota,omitempty"`
	MemoryLimit string `json:"memory_limit,omitempty" yaml:"memory_limit,omitempty"`
	MemorySwap  string `json:"memory_swap,omitempty" yaml:"memory_swap,omitempty"`

	// Health checks
	HealthCheck *HealthCheck `json:"healthcheck,omitempty" yaml:"healthcheck,omitempty"`

	// Labels and metadata
	Labels map[string]string `json:"labels,omitempty" yaml:"labels,omitempty"`

	// Platform-specific extensions
	Extensions map[string]interface{} `json:"extensions,omitempty" yaml:"extensions,omitempty"`

	// Source platform metadata
	Platform   Platform `json:"platform" yaml:"platform"`
	SourceFile string   `json:"source_file,omitempty" yaml:"source_file,omitempty"`
}

// PortMapping represents a port mapping between host and container
type PortMapping struct {
	HostIP        string `json:"host_ip,omitempty" yaml:"host_ip,omitempty"`
	HostPort      string `json:"host_port" yaml:"host_port"`
	ContainerPort string `json:"container_port" yaml:"container_port"`
	Protocol      string `json:"protocol,omitempty" yaml:"protocol,omitempty"` // tcp, udp
}

// VolumeMount represents a volume mount
type VolumeMount struct {
	Source   string `json:"source" yaml:"source"`
	Target   string `json:"target" yaml:"target"`
	Type     string `json:"type,omitempty" yaml:"type,omitempty"` // bind, volume, tmpfs
	ReadOnly bool   `json:"read_only,omitempty" yaml:"read_only,omitempty"`
	Mode     string `json:"mode,omitempty" yaml:"mode,omitempty"` // Z, z, shared, private, slave
}

// HealthCheck represents a container health check
type HealthCheck struct {
	Test        []string `json:"test" yaml:"test"`
	Interval    string   `json:"interval,omitempty" yaml:"interval,omitempty"`
	Timeout     string   `json:"timeout,omitempty" yaml:"timeout,omitempty"`
	Retries     int      `json:"retries,omitempty" yaml:"retries,omitempty"`
	StartPeriod string   `json:"start_period,omitempty" yaml:"start_period,omitempty"`
}

// Config represents a configuration file
type Config struct {
	Name     string `json:"name" yaml:"name"`
	Content  string `json:"content,omitempty" yaml:"content,omitempty"`
	File     string `json:"file,omitempty" yaml:"file,omitempty"`
	Template string `json:"template,omitempty" yaml:"template,omitempty"`
	Mode     string `json:"mode,omitempty" yaml:"mode,omitempty"`
}

// Secret represents a secret
type Secret struct {
	Name        string `json:"name" yaml:"name"`
	File        string `json:"file,omitempty" yaml:"file,omitempty"`
	Environment string `json:"environment,omitempty" yaml:"environment,omitempty"`
	External    bool   `json:"external,omitempty" yaml:"external,omitempty"`
}

// Network represents a Docker network
type Network struct {
	Name       string            `json:"name" yaml:"name"`
	Driver     string            `json:"driver,omitempty" yaml:"driver,omitempty"`
	DriverOpts map[string]string `json:"driver_opts,omitempty" yaml:"driver_opts,omitempty"`
	Attachable bool              `json:"attachable,omitempty" yaml:"attachable,omitempty"`
	External   bool              `json:"external,omitempty" yaml:"external,omitempty"`
	Internal   bool              `json:"internal,omitempty" yaml:"internal,omitempty"`
	IPAM       *IPAMConfig       `json:"ipam,omitempty" yaml:"ipam,omitempty"`
	Labels     map[string]string `json:"labels,omitempty" yaml:"labels,omitempty"`
}

// IPAMConfig represents IP address management configuration
type IPAMConfig struct {
	Driver  string            `json:"driver,omitempty" yaml:"driver,omitempty"`
	Config  []IPAMSubnet      `json:"config,omitempty" yaml:"config,omitempty"`
	Options map[string]string `json:"options,omitempty" yaml:"options,omitempty"`
}

// IPAMSubnet represents an IP subnet configuration
type IPAMSubnet struct {
	Subnet  string `json:"subnet,omitempty" yaml:"subnet,omitempty"`
	Gateway string `json:"gateway,omitempty" yaml:"gateway,omitempty"`
}

// Volume represents a named volume
type Volume struct {
	Name       string            `json:"name" yaml:"name"`
	Driver     string            `json:"driver,omitempty" yaml:"driver,omitempty"`
	DriverOpts map[string]string `json:"driver_opts,omitempty" yaml:"driver_opts,omitempty"`
	External   bool              `json:"external,omitempty" yaml:"external,omitempty"`
	Labels     map[string]string `json:"labels,omitempty" yaml:"labels,omitempty"`
}

// Application represents a complete application with all its components
type Application struct {
	Version  string              `json:"version,omitempty" yaml:"version,omitempty"`
	Services map[string]*Service `json:"services" yaml:"services"`
	Networks map[string]*Network `json:"networks,omitempty" yaml:"networks,omitempty"`
	Volumes  map[string]*Volume  `json:"volumes,omitempty" yaml:"volumes,omitempty"`
	Configs  map[string]*Config  `json:"configs,omitempty" yaml:"configs,omitempty"`
	Secrets  map[string]*Secret  `json:"secrets,omitempty" yaml:"secrets,omitempty"`

	// Includes for multi-file compositions
	Includes []string `json:"include,omitempty" yaml:"include,omitempty"`

	// Platform-specific extensions
	Extensions map[string]interface{} `json:"extensions,omitempty" yaml:"extensions,omitempty"`

	// Metadata
	Platform    Platform `json:"platform" yaml:"platform"`
	SourceFiles []string `json:"source_files,omitempty" yaml:"source_files,omitempty"`
}

// Validate performs basic validation on the application
func (app *Application) Validate() error {
	if app.Services == nil || len(app.Services) == 0 {
		return fmt.Errorf("application must have at least one service")
	}

	for name, service := range app.Services {
		if service.Name == "" {
			service.Name = name
		}
		if service.Image == "" {
			return fmt.Errorf("service %s must have an image", name)
		}
	}

	return nil
}

// String returns a string representation of the application
func (app *Application) String() string {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("Application (%s):\n", app.Platform))
	sb.WriteString(fmt.Sprintf("  Services: %d\n", len(app.Services)))
	sb.WriteString(fmt.Sprintf("  Networks: %d\n", len(app.Networks)))
	sb.WriteString(fmt.Sprintf("  Volumes: %d\n", len(app.Volumes)))
	sb.WriteString(fmt.Sprintf("  Configs: %d\n", len(app.Configs)))
	sb.WriteString(fmt.Sprintf("  Secrets: %d\n", len(app.Secrets)))
	return sb.String()
}
