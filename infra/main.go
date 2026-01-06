package main

import (
	"archive/tar"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
	"gopkg.in/yaml.v3"

	"cluster/infra/tailscale"
)

// Config holds the infrastructure configuration
type Config struct {
	Domain      string
	StackName   string
	ConfigPath  string
	RootPath    string
	SecretsPath string
	Nodes       []Node
	Networks    map[string]NetworkConfig
	Services    []Service
}

// Node represents a cluster node
type Node struct {
	Name        string
	TailscaleIP string
	Priority    int // Lower = higher priority (fast nodes first)
}

// NetworkConfig defines a Docker network
type NetworkConfig struct {
	Name       string
	Driver     string
	Subnet     string
	Gateway    string
	BridgeName string
	External   bool
	Attachable bool
}

// Service represents a containerized service
type Service struct {
	Name           string
	Image          string
	ContainerName  string
	Hostname       string
	Networks       []string
	Ports          []PortMapping
	Volumes        []VolumeMount
	Environment    map[string]string
	Labels         map[string]string
	Command        []string
	Entrypoint     []string
	User           string
	Devices        []string
	Restart        string
	Healthcheck    *Healthcheck
	DependsOn      []string
	Privileged     bool
	CapAdd         []string
	MemLimit       string
	MemReservation string
	CPUs           string
	ExtraHosts     []string
	Build          *BuildConfig
	Secrets        []SecretMount
	Configs        []ConfigMount
}

type PortMapping struct {
	HostPort      string
	ContainerPort string
	Protocol      string
	HostIP        string // "127.0.0.1" for localhost-only
}

type VolumeMount struct {
	Source   string
	Target   string
	ReadOnly bool
	Type     string // "bind", "volume", "tmpfs"
}

type SecretMount struct {
	Source string // Path to secret file
	Target string // Mount path in container
	Mode   string // File permissions
}

type ConfigMount struct {
	Source string
	Target string
	Mode   string
}

type Healthcheck struct {
	Test        []string
	Interval    string
	Timeout     string
	Retries     int
	StartPeriod string
}

type BuildConfig struct {
	Context    string
	Dockerfile string
}

// Infrastructure manages the entire stack
type Infrastructure struct {
	config *Config
	client *client.Client
	ctx    context.Context
}

// NewInfrastructure creates a new infrastructure manager
func NewInfrastructure(config *Config) (*Infrastructure, error) {
	cli, err := client.NewClientWithOpts(
		client.FromEnv,
		client.WithAPIVersionNegotiation(),
		client.WithVersion("1.44"), // Minimum required version
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create Docker client: %w", err)
	}

	return &Infrastructure{
		config: config,
		client: cli,
		ctx:    context.Background(),
	}, nil
}

// EnsureNetworks creates all required Docker networks
func (infra *Infrastructure) EnsureNetworks() error {
	ensureDefaultNetworks(infra.config)
	for name, netConfig := range infra.config.Networks {
		networkName := netConfig.Name
		if networkName == "" {
			networkName = name
		}
		log.Printf("Ensuring network: %s", networkName)

		// Check if network exists
		networks, err := infra.client.NetworkList(infra.ctx, types.NetworkListOptions{})
		if err != nil {
			return fmt.Errorf("failed to list networks: %w", err)
		}

		exists := false
		for _, net := range networks {
			if net.Name == networkName {
				exists = true
				log.Printf("  Network %s already exists", networkName)
				break
			}
		}

		if !exists {
			ipamConfig := []network.IPAMConfig{}
			if netConfig.Subnet != "" {
				ipamConfig = append(ipamConfig, network.IPAMConfig{
					Subnet:  netConfig.Subnet,
					Gateway: netConfig.Gateway,
				})
			}

			driverOpts := map[string]string{}
			if netConfig.BridgeName != "" {
				driverOpts["com.docker.network.bridge.name"] = netConfig.BridgeName
			}
			if netConfig.Name == "warp-nat-net" {
				driverOpts["com.docker.network.bridge.enable_ip_masquerade"] = "false"
			}

			createOpts := types.NetworkCreate{
				CheckDuplicate: true,
				Driver:         netConfig.Driver,
				EnableIPv6:     false,
				IPAM: &network.IPAM{
					Config: ipamConfig,
				},
				Options:    driverOpts,
				Attachable: netConfig.Attachable,
				Internal:   false,
			}

			_, err := infra.client.NetworkCreate(infra.ctx, networkName, createOpts)
			if err != nil {
				return fmt.Errorf("failed to create network %s: %w", networkName, err)
			}
			log.Printf("  Created network: %s", networkName)
		}
	}

	return nil
}

// DeployService deploys a single service
func (infra *Infrastructure) DeployService(svc Service) error {
	log.Printf("Deploying service: %s", svc.Name)

	// Ensure networks based on labels if not explicitly set
	svc.Networks = assignNetworks(svc)

	// Check if container exists
	containers, err := infra.client.ContainerList(infra.ctx, types.ContainerListOptions{
		All:     true,
		Filters: filters.NewArgs(filters.Arg("name", svc.ContainerName)),
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	// Remove existing container if it exists
	if len(containers) > 0 {
		log.Printf("  Removing existing container: %s", svc.ContainerName)
		err = infra.client.ContainerRemove(infra.ctx, svc.ContainerName, types.ContainerRemoveOptions{
			Force: true,
		})
		if err != nil {
			// Log warning but continue if container doesn't exist
			log.Printf("  Warning: Failed to remove container %s: %v (continuing anyway)", svc.ContainerName, err)
		}
	}

	// Build image if needed
	if svc.Build != nil {
		log.Printf("  Building image for %s...", svc.Name)
		if err := infra.buildImage(svc); err != nil {
			return fmt.Errorf("failed to build image: %w", err)
		}
	}

	// Prepare container config
	containerConfig := &container.Config{
		Image:       svc.Image,
		Hostname:    svc.Hostname,
		Env:         infra.envMapToSlice(svc.Environment),
		Labels:      svc.Labels,
		Cmd:         svc.Command,
		Healthcheck: infra.healthcheckToDocker(svc.Healthcheck),
	}
	if len(svc.Entrypoint) > 0 {
		containerConfig.Entrypoint = svc.Entrypoint
	}
	if svc.User != "" {
		containerConfig.User = svc.User
	}

	// Prepare host config
	hostConfig := &container.HostConfig{
		RestartPolicy: container.RestartPolicy{
			Name: svc.Restart,
		},
		Privileged:   svc.Privileged,
		CapAdd:       svc.CapAdd,
		ExtraHosts:   svc.ExtraHosts,
		Binds:        infra.volumesToBinds(svc.Volumes),
		PortBindings: infra.portsToBindings(svc.Ports),
		Resources: container.Resources{
			Memory:            infra.parseMemory(svc.MemLimit),
			MemoryReservation: infra.parseMemory(svc.MemReservation),
			NanoCPUs:          infra.parseCPUs(svc.CPUs),
		},
	}
	// Add devices
	if len(svc.Devices) > 0 {
		devices := make([]container.DeviceMapping, 0, len(svc.Devices))
		for _, dev := range svc.Devices {
			devices = append(devices, container.DeviceMapping{
				PathOnHost:        dev,
				PathInContainer:   dev,
				CgroupPermissions: "rwm",
			})
		}
		hostConfig.Devices = devices
	}

	// Create container
	resp, err := infra.client.ContainerCreate(
		infra.ctx,
		containerConfig,
		hostConfig,
		nil,
		nil,
		svc.ContainerName,
	)
	if err != nil {
		return fmt.Errorf("failed to create container: %w", err)
	}

	// Connect to networks
	for _, netName := range svc.Networks {
		fullNetName := netName
		if infra.config.StackName != "" {
			fullNetName = infra.config.StackName + "_" + netName
			if netName == "default" {
				fullNetName = infra.config.StackName + "_default"
			}
		}

		err = infra.client.NetworkConnect(infra.ctx, fullNetName, resp.ID, nil)
		if err != nil {
			log.Printf("  Warning: failed to connect to network %s: %v", fullNetName, err)
		} else {
			log.Printf("  Connected to network: %s", fullNetName)
		}
	}

	// Start container
	err = infra.client.ContainerStart(infra.ctx, resp.ID, types.ContainerStartOptions{})
	if err != nil {
		return fmt.Errorf("failed to start container: %w", err)
	}

	log.Printf("  Started container: %s", svc.ContainerName)
	return nil
}

// buildImage builds a Docker image using the Docker build API
func (infra *Infrastructure) buildImage(svc Service) error {
	if svc.Build == nil {
		return nil
	}

	buildCtx := svc.Build.Context
	if buildCtx == "" {
		buildCtx = "."
	}

	// Convert relative path to absolute
	if !filepath.IsAbs(buildCtx) {
		absPath, err := filepath.Abs(buildCtx)
		if err != nil {
			return fmt.Errorf("failed to resolve build context path: %w", err)
		}
		buildCtx = absPath
	}

	// Check if context directory exists
	if _, err := os.Stat(buildCtx); os.IsNotExist(err) {
		return fmt.Errorf("build context directory does not exist: %s", buildCtx)
	}

	dockerfile := svc.Build.Dockerfile
	if dockerfile == "" {
		dockerfile = "Dockerfile"
	}

	// Create build context tar
	buildContext, err := createBuildContext(buildCtx, dockerfile)
	if err != nil {
		return fmt.Errorf("failed to create build context: %w", err)
	}
	defer buildContext.Close()

	// Build options
	buildOptions := types.ImageBuildOptions{
		Dockerfile: dockerfile,
		Tags:       []string{svc.Image},
		Remove:     true, // Remove intermediate containers
		PullParent: false,
	}

	// Build the image
	buildResponse, err := infra.client.ImageBuild(infra.ctx, buildContext, buildOptions)
	if err != nil {
		return fmt.Errorf("failed to start image build: %w", err)
	}
	defer buildResponse.Body.Close()

	// Stream build output
	decoder := json.NewDecoder(buildResponse.Body)
	for {
		var stream struct {
			Stream string `json:"stream"`
			Error  string `json:"error"`
		}
		if err := decoder.Decode(&stream); err != nil {
			if err == io.EOF {
				break
			}
			return fmt.Errorf("failed to decode build output: %w", err)
		}

		if stream.Stream != "" {
			log.Printf("  %s", strings.TrimSpace(stream.Stream))
		}
		if stream.Error != "" {
			return fmt.Errorf("build error: %s", stream.Error)
		}
	}

	log.Printf("  Successfully built image: %s", svc.Image)
	return nil
}

// createBuildContext creates a tar archive of the build context
func createBuildContext(contextPath, dockerfile string) (io.ReadCloser, error) {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)

	// Walk the context directory and add files to tar
	err := filepath.Walk(contextPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip directories - tar automatically creates directory entries when files are added
		if info.IsDir() {
			return nil
		}

		// Get relative path from context
		relPath, err := filepath.Rel(contextPath, path)
		if err != nil {
			return err
		}

		// Skip if outside context (shouldn't happen, but be safe)
		if strings.HasPrefix(relPath, "..") {
			return nil
		}

		// Read file
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()

		// Create tar header
		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return err
		}
		header.Name = relPath

		// Write header
		if err := tw.WriteHeader(header); err != nil {
			return err
		}

		// Write file content
		if _, err := io.Copy(tw, file); err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		tw.Close()
		return nil, fmt.Errorf("failed to walk build context: %w", err)
	}

	if err := tw.Close(); err != nil {
		return nil, fmt.Errorf("failed to close tar writer: %w", err)
	}

	return io.NopCloser(&buf), nil
}

// Helper functions
func (infra *Infrastructure) envMapToSlice(env map[string]string) []string {
	result := make([]string, 0, len(env))
	for k, v := range env {
		result = append(result, fmt.Sprintf("%s=%s", k, v))
	}
	return result
}

func (infra *Infrastructure) volumesToBinds(volumes []VolumeMount) []string {
	binds := make([]string, 0, len(volumes))
	for _, vol := range volumes {
		if vol.Type == "bind" {
			// Convert relative paths to absolute paths
			sourcePath := vol.Source
			if !filepath.IsAbs(sourcePath) {
				absPath, err := filepath.Abs(sourcePath)
				if err == nil {
					sourcePath = absPath
				}
			}
			ro := ""
			if vol.ReadOnly {
				ro = ":ro"
			}
			binds = append(binds, fmt.Sprintf("%s:%s%s", sourcePath, vol.Target, ro))
		}
	}
	return binds
}

func (infra *Infrastructure) portsToBindings(ports []PortMapping) nat.PortMap {
	bindings := nat.PortMap{}
	for _, port := range ports {
		containerPort, _ := nat.NewPort(port.Protocol, port.ContainerPort)
		hostIP := port.HostIP
		if hostIP == "" {
			hostIP = "0.0.0.0"
		}
		bindings[containerPort] = []nat.PortBinding{
			{
				HostIP:   hostIP,
				HostPort: port.HostPort,
			},
		}
	}
	return bindings
}

func (infra *Infrastructure) healthcheckToDocker(hc *Healthcheck) *container.HealthConfig {
	if hc == nil {
		return nil
	}
	return &container.HealthConfig{
		Test:        hc.Test,
		Interval:    parseDuration(hc.Interval),
		Timeout:     parseDuration(hc.Timeout),
		Retries:     hc.Retries,
		StartPeriod: parseDuration(hc.StartPeriod),
	}
}

func (infra *Infrastructure) parseMemory(mem string) int64 {
	// Parse memory strings like "4G", "512M", "1.5G", etc.
	if mem == "" {
		return 0
	}

	var bytes int64
	var unit string
	fmt.Sscanf(mem, "%d%s", &bytes, &unit)

	switch strings.ToUpper(unit) {
	case "G", "GB":
		return bytes * 1024 * 1024 * 1024
	case "M", "MB":
		return bytes * 1024 * 1024
	case "K", "KB":
		return bytes * 1024
	default:
		return bytes
	}
}

func (infra *Infrastructure) parseCPUs(cpus string) int64 {
	// Parse CPU string like "2.0" or "4" to nanoCPUs
	if cpus == "" {
		return 0
	}

	var cpu float64
	fmt.Sscanf(cpus, "%f", &cpu)
	// Convert to nanoCPUs (1 CPU = 1,000,000,000 nanoCPUs)
	return int64(cpu * 1e9)
}

func parseDuration(dur string) time.Duration {
	// Parse strings like "30s", "10m", etc.
	d, err := time.ParseDuration(dur)
	if err != nil {
		return 0
	}
	return d
}

func main() {
	// Load configuration
	config := loadConfig()

	// Create infrastructure manager
	infra, err := NewInfrastructure(config)
	if err != nil {
		log.Fatalf("Failed to create infrastructure: %v", err)
	}
	defer infra.client.Close()

	// Discover nodes via Tailscale for logging and informational purposes
	// Note: In the agent (cmd/agent/main.go), node discovery is integrated with gossip state
	// and DNS updates. In this standalone deployment tool, we only log discovered nodes.
	nodeIPs, err := tailscale.DiscoverPeers()
	if err != nil {
		log.Printf("Warning: Failed to discover nodes via Tailscale: %v (continuing anyway)", err)
		nodeIPs = []string{}
	} else {
		log.Printf("Discovered %d nodes via Tailscale", len(nodeIPs))
		for _, ip := range nodeIPs {
			log.Printf("  - Node IP: %s", ip)
		}
	}

	// Ensure networks exist
	if err := infra.EnsureNetworks(); err != nil {
		log.Fatalf("Failed to ensure networks: %v", err)
	}

	// Deploy services
	for _, svc := range config.Services {
		if err := infra.DeployService(svc); err != nil {
			log.Printf("Error deploying %s: %v", svc.Name, err)
		}
	}

	// Note: Traefik configuration is now handled dynamically by the Constellation Agent
	// via the HTTP provider API. No static config generation is needed.
	// The agent will automatically discover services and generate Traefik config from gossip state.
	log.Println("Note: Traefik configuration is managed dynamically by Constellation Agent")

	log.Println("Deployment complete!")
}

func loadConfig() *Config {
	// Try to load from config file first
	configFile := getEnv("CONFIG_FILE", "")
	if configFile != "" {
		if config, err := loadConfigFromFile(configFile); err == nil {
			// Merge with environment variables (env takes precedence)
			mergeConfigWithEnv(config)
			return config
		} else {
			log.Printf("Warning: Failed to load config file %s: %v, using defaults", configFile, err)
		}
	}

	// Fall back to environment variables only
	return &Config{
		Domain:      getEnv("DOMAIN", "bolabaden.org"),
		StackName:   getEnv("STACK_NAME", "my-media-stack"),
		ConfigPath:  getEnv("CONFIG_PATH", "./volumes"),
		RootPath:    getEnv("ROOT_PATH", "."),
		SecretsPath: getEnv("SECRETS_PATH", "./secrets"),
		Networks:    defineNetworks(),
		Services:    defineServices(),
	}
}

// loadConfigFromFile loads configuration from YAML or JSON file
func loadConfigFromFile(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	config := &Config{}

	// Try YAML first
	if strings.HasSuffix(filename, ".yaml") || strings.HasSuffix(filename, ".yml") {
		if err := loadYAMLConfig(data, config); err != nil {
			return nil, fmt.Errorf("failed to parse YAML config: %w", err)
		}
		return config, nil
	}

	// Try JSON
	if strings.HasSuffix(filename, ".json") {
		if err := json.Unmarshal(data, config); err != nil {
			return nil, fmt.Errorf("failed to parse JSON config: %w", err)
		}
		return config, nil
	}

	// Try both formats
	if err := loadYAMLConfig(data, config); err == nil {
		return config, nil
	}
	if err := json.Unmarshal(data, config); err == nil {
		return config, nil
	}

	return nil, fmt.Errorf("unable to parse config file as YAML or JSON")
}

// loadYAMLConfig loads YAML configuration using gopkg.in/yaml.v3
func loadYAMLConfig(data []byte, config *Config) error {
	// Uses gopkg.in/yaml.v3 for full YAML parsing support
	var yamlData map[string]interface{}
	if err := yaml.Unmarshal(data, &yamlData); err != nil {
		return err
	}

	// Extract values
	if domain, ok := yamlData["domain"].(string); ok {
		config.Domain = domain
	}
	if stackName, ok := yamlData["stack_name"].(string); ok {
		config.StackName = stackName
	}
	if configPath, ok := yamlData["config_path"].(string); ok {
		config.ConfigPath = configPath
	}
	if rootPath, ok := yamlData["root_path"].(string); ok {
		config.RootPath = rootPath
	}
	if secretsPath, ok := yamlData["secrets_path"].(string); ok {
		config.SecretsPath = secretsPath
	}

	// Networks and services are defined in code, not loaded from config
	config.Networks = defineNetworks()
	config.Services = defineServices()

	return nil
}

// mergeConfigWithEnv merges environment variables into config (env takes precedence)
func mergeConfigWithEnv(config *Config) {
	if val := getEnv("DOMAIN", ""); val != "" {
		config.Domain = val
	}
	if val := getEnv("STACK_NAME", ""); val != "" {
		config.StackName = val
	}
	if val := getEnv("CONFIG_PATH", ""); val != "" {
		config.ConfigPath = val
	}
	if val := getEnv("ROOT_PATH", ""); val != "" {
		config.RootPath = val
	}
	if val := getEnv("SECRETS_PATH", ""); val != "" {
		config.SecretsPath = val
	}
}

func getEnv(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}

func defineNetworks() map[string]NetworkConfig {
	return map[string]NetworkConfig{
		"warp-nat-net": {
			Name:       "warp-nat-net",
			Driver:     "bridge",
			Subnet:     getEnv("WARP_NAT_NET_SUBNET", "10.0.2.0/24"),
			Gateway:    getEnv("WARP_NAT_NET_GATEWAY", "10.0.2.1"),
			BridgeName: "br_warp-nat-net",
			External:   true,
			Attachable: true,
		},
		"publicnet": {
			Name:       getEnv("STACK_NAME", "my-media-stack") + "_publicnet",
			Driver:     "bridge",
			Subnet:     getEnv("PUBLICNET_SUBNET", "10.76.0.0/16"),
			Gateway:    getEnv("PUBLICNET_GATEWAY", "10.76.0.1"),
			BridgeName: "br_publicnet",
			Attachable: true,
		},
		"backend": {
			Name:       getEnv("STACK_NAME", "my-media-stack") + "_backend",
			Driver:     "bridge",
			Subnet:     getEnv("BACKEND_SUBNET", "10.0.7.0/24"),
			Gateway:    getEnv("BACKEND_GATEWAY", "10.0.7.1"),
			BridgeName: "br_backend",
			Attachable: true,
		},
		"nginx_net": {
			Name:       getEnv("STACK_NAME", "my-media-stack") + "_nginx_net",
			Driver:     "bridge",
			Subnet:     getEnv("NGINX_TRAEFIK_SUBNET", "10.0.8.0/24"),
			Gateway:    getEnv("NGINX_TRAEFIK_GATEWAY", "10.0.8.1"),
			BridgeName: "br_nginx_net",
			Attachable: true,
		},
		"default": {
			Name:       getEnv("STACK_NAME", "my-media-stack") + "_default",
			Driver:     "bridge",
			Attachable: true,
		},
	}
}

func defineServices() []Service {
	config := &Config{
		Domain:      getEnv("DOMAIN", "bolabaden.org"),
		StackName:   getEnv("STACK_NAME", "my-media-stack"),
		ConfigPath:  getEnv("CONFIG_PATH", "./volumes"),
		RootPath:    getEnv("ROOT_PATH", "."),
		SecretsPath: getEnv("SECRETS_PATH", "./secrets"),
	}
	return defineServicesFromConfig(config)
}
