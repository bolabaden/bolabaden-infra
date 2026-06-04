package paas

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// ParseDockerCompose parses a Docker Compose YAML file or content
func ParseDockerCompose(content string) (*Application, error) {
	var data map[string]interface{}
	if err := yaml.Unmarshal([]byte(content), &data); err != nil {
		return nil, fmt.Errorf("failed to parse docker-compose YAML: %w", err)
	}

	app := &Application{
		Platform: PlatformDockerCompose,
		Services: make(map[string]*Service),
		Networks: make(map[string]*Network),
		Volumes:  make(map[string]*Volume),
		Configs:  make(map[string]*Config),
		Secrets:  make(map[string]*Secret),
	}

	// Parse version
	if version, ok := data["version"].(string); ok {
		app.Version = version
	}

	// Parse includes
	if includes, ok := data["include"].([]interface{}); ok {
		for _, inc := range includes {
			if incStr, ok := inc.(string); ok {
				app.Includes = append(app.Includes, incStr)
			}
		}
	}

	// Parse services
	if servicesData, ok := data["services"].(map[string]interface{}); ok {
		for name, serviceData := range servicesData {
			service, err := parseService(name, serviceData.(map[string]interface{}))
			if err != nil {
				return nil, fmt.Errorf("failed to parse service %s: %w", name, err)
			}
			app.Services[name] = service
		}
	}

	// Parse networks
	if networksData, ok := data["networks"].(map[string]interface{}); ok {
		for name, networkData := range networksData {
			network, err := parseNetwork(name, networkData.(map[string]interface{}))
			if err != nil {
				return nil, fmt.Errorf("failed to parse network %s: %w", name, err)
			}
			app.Networks[name] = network
		}
	}

	// Parse volumes
	if volumesData, ok := data["volumes"].(map[string]interface{}); ok {
		for name, volumeData := range volumesData {
			volume, err := parseVolume(name, volumeData.(map[string]interface{}))
			if err != nil {
				return nil, fmt.Errorf("failed to parse volume %s: %w", name, err)
			}
			app.Volumes[name] = volume
		}
	}

	// Parse configs
	if configsData, ok := data["configs"].(map[string]interface{}); ok {
		for name, configData := range configsData {
			config, err := parseConfig(name, configData.(map[string]interface{}))
			if err != nil {
				return nil, fmt.Errorf("failed to parse config %s: %w", name, err)
			}
			app.Configs[name] = config
		}
	}

	// Parse secrets
	if secretsData, ok := data["secrets"].(map[string]interface{}); ok {
		for name, secretData := range secretsData {
			secret, err := parseSecret(name, secretData.(map[string]interface{}))
			if err != nil {
				return nil, fmt.Errorf("failed to parse secret %s: %w", name, err)
			}
			app.Secrets[name] = secret
		}
	}

	// Store extensions
	app.Extensions = make(map[string]interface{})
	for key, value := range data {
		if !isStandardKey(key) {
			app.Extensions[key] = value
		}
	}

	return app, nil
}

func parseService(name string, data map[string]interface{}) (*Service, error) {
	service := &Service{
		Name:       name,
		Platform:   PlatformDockerCompose,
		Environment: make(map[string]string),
		Labels:     make(map[string]string),
		Extensions: make(map[string]interface{}),
	}

	for key, value := range data {
		switch key {
		case "image":
			service.Image = toString(value)
		case "container_name":
			service.ContainerName = toString(value)
		case "hostname":
			service.Hostname = toString(value)
		case "ports":
			ports, err := parsePorts(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse ports: %w", err)
			}
			service.Ports = ports
		case "expose":
			expose, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse expose: %w", err)
			}
			service.Expose = expose
		case "networks":
			networks, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse networks: %w", err)
			}
			service.Networks = networks
		case "environment":
			env, err := parseEnvironment(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse environment: %w", err)
			}
			service.Environment = env
		case "env_file":
			envFile, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse env_file: %w", err)
			}
			service.EnvFile = envFile
		case "command":
			command, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse command: %w", err)
			}
			service.Command = command
		case "entrypoint":
			entrypoint, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse entrypoint: %w", err)
			}
			service.Entrypoint = entrypoint
		case "working_dir":
			service.WorkingDir = toString(value)
		case "volumes":
			volumes, err := parseVolumes(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse volumes: %w", err)
			}
			service.Volumes = volumes
		case "depends_on":
			dependsOn, err := parseDependsOn(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse depends_on: %w", err)
			}
			service.DependsOn = dependsOn
		case "links":
			links, err := toStringSlice(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse links: %w", err)
			}
			service.Links = links
		case "restart":
			service.Restart = toString(value)
		case "privileged":
			service.Privileged = toBool(value)
		case "user":
			service.User = toString(value)
		case "group":
			service.Group = toString(value)
		case "cpu_shares":
			if intVal, ok := value.(int); ok {
				service.CPUShares = intVal
			}
		case "cpu_quota":
			if intVal, ok := value.(int); ok {
				service.CPUQuota = intVal
			}
		case "mem_limit":
			service.MemoryLimit = toString(value)
		case "memswap_limit":
			service.MemorySwap = toString(value)
		case "healthcheck":
			healthcheck, err := parseHealthCheck(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse healthcheck: %w", err)
			}
			service.HealthCheck = healthcheck
		case "labels":
			labels, err := toStringMap(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse labels: %w", err)
			}
			service.Labels = labels
		default:
			service.Extensions[key] = value
		}
	}

	return service, nil
}

func parsePorts(value interface{}) ([]PortMapping, error) {
	var ports []PortMapping

	switch v := value.(type) {
	case []interface{}:
		for _, portStr := range v {
			port, err := parsePortMapping(toString(portStr))
			if err != nil {
				return nil, err
			}
			ports = append(ports, port)
		}
	case []string:
		for _, portStr := range v {
			port, err := parsePortMapping(portStr)
			if err != nil {
				return nil, err
			}
			ports = append(ports, port)
		}
	}

	return ports, nil
}

func parsePortMapping(portStr string) (PortMapping, error) {
	// Handle formats like:
	// - "8080:80"
	// - "127.0.0.1:8080:80"
	// - "8080:80/tcp"
	// - "8080:80/udp"
	// - "${VAR:-8080}:${VAR:-80}"
	// - "${VAR:-8080}:${VAR:-80}/tcp"

	// First expand environment variables in the entire string
	expandedPortStr := expandEnvVars(portStr)

	parts := strings.Split(expandedPortStr, "/")
	protocol := "tcp"
	if len(parts) > 1 {
		protocol = parts[1]
	}

	hostParts := strings.Split(parts[0], ":")
	if len(hostParts) == 2 {
		return PortMapping{
			HostPort:      hostParts[0],
			ContainerPort: hostParts[1],
			Protocol:      protocol,
		}, nil
	} else if len(hostParts) == 3 {
		return PortMapping{
			HostIP:        hostParts[0],
			HostPort:      hostParts[1],
			ContainerPort: hostParts[2],
			Protocol:      protocol,
		}, nil
	}

	return PortMapping{}, fmt.Errorf("invalid port mapping format: %s", portStr)
}

// expandEnvVars handles basic environment variable substitution in strings
// Supports patterns like ${VAR:-default} and ${VAR}
func parseDependsOn(value interface{}) ([]string, error) {
	// depends_on can be:
	// - Simple list: ["service1", "service2"]
	// - Map with conditions: {"service1": {"condition": "service_healthy"}}

	switch v := value.(type) {
	case []interface{}:
		// Simple list format
		var dependsOn []string
		for _, item := range v {
			dependsOn = append(dependsOn, toString(item))
		}
		return dependsOn, nil
	case map[string]interface{}:
		// Map format with conditions
		var dependsOn []string
		for serviceName := range v {
			dependsOn = append(dependsOn, serviceName)
		}
		return dependsOn, nil
	case map[interface{}]interface{}:
		// YAML can sometimes parse maps as map[interface{}]interface{}
		var dependsOn []string
		for serviceName := range v {
			if name, ok := serviceName.(string); ok {
				dependsOn = append(dependsOn, name)
			}
		}
		return dependsOn, nil
	default:
		return nil, fmt.Errorf("cannot convert to string slice: %T", value)
	}
}

func expandEnvVars(s string) string {
	// Simple regex-based replacement for common patterns
	// ${VAR:-default} -> default
	// ${VAR} -> "" (empty if not set)

	result := s

	// Handle ${VAR:-default} pattern
	for strings.Contains(result, "${") && strings.Contains(result, ":-") && strings.Contains(result, "}") {
		start := strings.Index(result, "${")
		end := strings.Index(result[start:], "}")
		if end == -1 {
			break
		}
		end += start

		varPart := result[start+2 : end]
		colonDash := strings.Index(varPart, ":-")
		if colonDash != -1 {
			varName := varPart[:colonDash]
			defaultValue := varPart[colonDash+2:]

			// Try to get environment variable
			if envValue := os.Getenv(varName); envValue != "" {
				result = strings.Replace(result, result[start:end+1], envValue, 1)
			} else {
				result = strings.Replace(result, result[start:end+1], defaultValue, 1)
			}
		} else {
			break
		}
	}
	return result
}

func parseVolumes(value interface{}) ([]VolumeMount, error) {
	var volumes []VolumeMount

	switch v := value.(type) {
	case []interface{}:
		for _, volStr := range v {
			volume, err := parseVolumeMount(toString(volStr))
			if err != nil {
				return nil, err
			}
			volumes = append(volumes, volume)
		}
	case []string:
		for _, volStr := range v {
			volume, err := parseVolumeMount(volStr)
			if err != nil {
				return nil, err
			}
			volumes = append(volumes, volume)
		}
	}

	return volumes, nil
}

func parseVolumeMount(volStr string) (VolumeMount, error) {
	// Handle formats like:
	// - "/host/path:/container/path"
	// - "/host/path:/container/path:ro"
	// - "volume_name:/container/path"
	// - "volume_name:/container/path:Z"

	parts := strings.Split(volStr, ":")
	if len(parts) < 2 {
		return VolumeMount{}, fmt.Errorf("invalid volume format: %s", volStr)
	}

	volume := VolumeMount{
		Source: parts[0],
		Target: parts[1],
	}

	if len(parts) > 2 {
		options := strings.Split(parts[2], ",")
		for _, option := range options {
			switch option {
			case "ro", "readonly":
				volume.ReadOnly = true
			case "rw":
				volume.ReadOnly = false
			case "Z", "z", "shared", "private", "slave":
				volume.Mode = option
			}
		}
	}

	// Determine type
	if strings.Contains(volume.Source, "/") || strings.HasPrefix(volume.Source, ".") || strings.HasPrefix(volume.Source, "~") {
		volume.Type = "bind"
	} else {
		volume.Type = "volume"
	}

	return volume, nil
}

func parseEnvironment(value interface{}) (map[string]string, error) {
	env := make(map[string]string)

	switch v := value.(type) {
	case map[string]interface{}:
		for key, val := range v {
			env[key] = toString(val)
		}
	case []interface{}:
		for _, envStr := range v {
			parts := strings.SplitN(toString(envStr), "=", 2)
			if len(parts) == 2 {
				env[parts[0]] = parts[1]
			}
		}
	case []string:
		for _, envStr := range v {
			parts := strings.SplitN(envStr, "=", 2)
			if len(parts) == 2 {
				env[parts[0]] = parts[1]
			}
		}
	}

	return env, nil
}

func parseHealthCheck(value interface{}) (*HealthCheck, error) {
	data, ok := value.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("healthcheck must be a map")
	}

	hc := &HealthCheck{}

	for key, val := range data {
		switch key {
		case "test":
			test, err := toStringSlice(val)
			if err != nil {
				return nil, fmt.Errorf("failed to parse test: %w", err)
			}
			hc.Test = test
		case "interval":
			hc.Interval = toString(val)
		case "timeout":
			hc.Timeout = toString(val)
		case "retries":
			if intVal, ok := val.(int); ok {
				hc.Retries = intVal
			}
		case "start_period":
			hc.StartPeriod = toString(val)
		}
	}

	return hc, nil
}

func parseNetwork(name string, data map[string]interface{}) (*Network, error) {
	network := &Network{Name: name}

	for key, value := range data {
		switch key {
		case "driver":
			network.Driver = toString(value)
		case "driver_opts":
			opts, err := toStringMap(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse driver_opts: %w", err)
			}
			network.DriverOpts = opts
		case "attachable":
			network.Attachable = toBool(value)
		case "external":
			network.External = toBool(value)
		case "internal":
			network.Internal = toBool(value)
		case "ipam":
			ipam, err := parseIPAM(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse ipam: %w", err)
			}
			network.IPAM = ipam
		case "labels":
			labels, err := toStringMap(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse labels: %w", err)
			}
			network.Labels = labels
		}
	}

	return network, nil
}

func parseVolume(name string, data map[string]interface{}) (*Volume, error) {
	volume := &Volume{Name: name}

	for key, value := range data {
		switch key {
		case "driver":
			volume.Driver = toString(value)
		case "driver_opts":
			opts, err := toStringMap(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse driver_opts: %w", err)
			}
			volume.DriverOpts = opts
		case "external":
			volume.External = toBool(value)
		case "labels":
			labels, err := toStringMap(value)
			if err != nil {
				return nil, fmt.Errorf("failed to parse labels: %w", err)
			}
			volume.Labels = labels
		}
	}

	return volume, nil
}

func parseConfig(name string, data map[string]interface{}) (*Config, error) {
	config := &Config{Name: name}

	for key, value := range data {
		switch key {
		case "content":
			config.Content = toString(value)
		case "file":
			config.File = toString(value)
		case "template":
			config.Template = toString(value)
		case "mode":
			config.Mode = toString(value)
		}
	}

	return config, nil
}

func parseSecret(name string, data map[string]interface{}) (*Secret, error) {
	secret := &Secret{Name: name}

	for key, value := range data {
		switch key {
		case "file":
			secret.File = toString(value)
		case "environment":
			secret.Environment = toString(value)
		case "external":
			secret.External = toBool(value)
		}
	}

	return secret, nil
}

func parseIPAM(value interface{}) (*IPAMConfig, error) {
	data, ok := value.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("ipam must be a map")
	}

	ipam := &IPAMConfig{}

	for key, val := range data {
		switch key {
		case "driver":
			ipam.Driver = toString(val)
		case "config":
			config, err := parseIPAMSubnets(val)
			if err != nil {
				return nil, fmt.Errorf("failed to parse config: %w", err)
			}
			ipam.Config = config
		case "options":
			options, err := toStringMap(val)
			if err != nil {
				return nil, fmt.Errorf("failed to parse options: %w", err)
			}
			ipam.Options = options
		}
	}

	return ipam, nil
}

func parseIPAMSubnets(value interface{}) ([]IPAMSubnet, error) {
	var subnets []IPAMSubnet

	switch v := value.(type) {
	case []interface{}:
		for _, item := range v {
			if data, ok := item.(map[string]interface{}); ok {
				subnet := IPAMSubnet{}
				for key, val := range data {
					switch key {
					case "subnet":
						subnet.Subnet = toString(val)
					case "gateway":
						subnet.Gateway = toString(val)
					}
				}
				subnets = append(subnets, subnet)
			}
		}
	}

	return subnets, nil
}

// Helper functions
func toString(value interface{}) string {
	if value == nil {
		return ""
	}
	if str, ok := value.(string); ok {
		return str
	}
	return fmt.Sprintf("%v", value)
}

func toBool(value interface{}) bool {
	if b, ok := value.(bool); ok {
		return b
	}
	if str := toString(value); str != "" {
		if str == "true" || str == "1" || str == "yes" {
			return true
		}
	}
	return false
}

func toStringSlice(value interface{}) ([]string, error) {
	var result []string

	switch v := value.(type) {
	case []interface{}:
		for _, item := range v {
			result = append(result, toString(item))
		}
	case []string:
		result = v
	case string:
		result = []string{v}
	default:
		return nil, fmt.Errorf("cannot convert to string slice: %T", value)
	}

	return result, nil
}

func toStringMap(value interface{}) (map[string]string, error) {
	result := make(map[string]string)

	switch v := value.(type) {
	case map[string]interface{}:
		for key, val := range v {
			result[key] = toString(val)
		}
	case map[string]string:
		result = v
	default:
		return nil, fmt.Errorf("cannot convert to string map: %T", value)
	}

	return result, nil
}

func isStandardKey(key string) bool {
	standardKeys := []string{
		"version", "services", "networks", "volumes", "configs", "secrets", "include",
	}
	for _, k := range standardKeys {
		if k == key {
			return true
		}
	}
	return false
}

// SerializeDockerCompose converts an Application to Docker Compose YAML
func SerializeDockerCompose(app *Application) (string, error) {
	data := make(map[string]interface{})

	// Version
	if app.Version != "" {
		data["version"] = app.Version
	}

	// Includes
	if len(app.Includes) > 0 {
		data["include"] = app.Includes
	}

	// Services
	if len(app.Services) > 0 {
		servicesData := make(map[string]interface{})
		for name, service := range app.Services {
			serviceData, err := serializeService(service)
			if err != nil {
				return "", fmt.Errorf("failed to serialize service %s: %w", name, err)
			}
			servicesData[name] = serviceData
		}
		data["services"] = servicesData
	}

	// Networks
	if len(app.Networks) > 0 {
		networksData := make(map[string]interface{})
		for name, network := range app.Networks {
			networkData, err := serializeNetwork(network)
			if err != nil {
				return "", fmt.Errorf("failed to serialize network %s: %w", name, err)
			}
			networksData[name] = networkData
		}
		data["networks"] = networksData
	}

	// Volumes
	if len(app.Volumes) > 0 {
		volumesData := make(map[string]interface{})
		for name, volume := range app.Volumes {
			volumeData, err := serializeVolume(volume)
			if err != nil {
				return "", fmt.Errorf("failed to serialize volume %s: %w", name, err)
			}
			volumesData[name] = volumeData
		}
		data["volumes"] = volumesData
	}

	// Configs
	if len(app.Configs) > 0 {
		configsData := make(map[string]interface{})
		for name, config := range app.Configs {
			configData, err := serializeConfig(config)
			if err != nil {
				return "", fmt.Errorf("failed to serialize config %s: %w", name, err)
			}
			configsData[name] = configData
		}
		data["configs"] = configsData
	}

	// Secrets
	if len(app.Secrets) > 0 {
		secretsData := make(map[string]interface{})
		for name, secret := range app.Secrets {
			secretData, err := serializeSecret(secret)
			if err != nil {
				return "", fmt.Errorf("failed to serialize secret %s: %w", name, err)
			}
			secretsData[name] = secretData
		}
		data["secrets"] = secretsData
	}

	// Extensions
	for key, value := range app.Extensions {
		data[key] = value
	}

	yamlData, err := yaml.Marshal(data)
	if err != nil {
		return "", fmt.Errorf("failed to marshal to YAML: %w", err)
	}

	return string(yamlData), nil
}

func serializeService(service *Service) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Basic fields
	if service.Image != "" {
		data["image"] = service.Image
	}
	if service.ContainerName != "" {
		data["container_name"] = service.ContainerName
	}
	if service.Hostname != "" {
		data["hostname"] = service.Hostname
	}

	// Ports
	if len(service.Ports) > 0 {
		var ports []string
		for _, port := range service.Ports {
			portStr := port.ContainerPort
			if port.HostPort != "" {
				if port.HostIP != "" {
					portStr = fmt.Sprintf("%s:%s:%s", port.HostIP, port.HostPort, port.ContainerPort)
				} else {
					portStr = fmt.Sprintf("%s:%s", port.HostPort, port.ContainerPort)
				}
			}
			if port.Protocol != "" && port.Protocol != "tcp" {
				portStr = fmt.Sprintf("%s/%s", portStr, port.Protocol)
			}
			ports = append(ports, portStr)
		}
		data["ports"] = ports
	}

	// Expose
	if len(service.Expose) > 0 {
		data["expose"] = service.Expose
	}

	// Networks
	if len(service.Networks) > 0 {
		data["networks"] = service.Networks
	}

	// Environment
	if len(service.Environment) > 0 {
		data["environment"] = service.Environment
	}

	// Env file
	if len(service.EnvFile) > 0 {
		data["env_file"] = service.EnvFile
	}

	// Command
	if len(service.Command) > 0 {
		data["command"] = service.Command
	}

	// Entrypoint
	if len(service.Entrypoint) > 0 {
		data["entrypoint"] = service.Entrypoint
	}

	// Working dir
	if service.WorkingDir != "" {
		data["working_dir"] = service.WorkingDir
	}

	// Volumes
	if len(service.Volumes) > 0 {
		var volumes []string
		for _, volume := range service.Volumes {
			volStr := fmt.Sprintf("%s:%s", volume.Source, volume.Target)
			if volume.ReadOnly {
				volStr += ":ro"
			}
			if volume.Mode != "" {
				volStr += ":" + volume.Mode
			}
			volumes = append(volumes, volStr)
		}
		data["volumes"] = volumes
	}

	// Dependencies
	if len(service.DependsOn) > 0 {
		data["depends_on"] = service.DependsOn
	}

	// Links
	if len(service.Links) > 0 {
		data["links"] = service.Links
	}

	// Restart
	if service.Restart != "" {
		data["restart"] = service.Restart
	}

	// Privileged
	if service.Privileged {
		data["privileged"] = true
	}

	// User/Group
	if service.User != "" {
		data["user"] = service.User
	}
	if service.Group != "" {
		data["group"] = service.Group
	}

	// Resources
	if service.CPUShares > 0 {
		data["cpu_shares"] = service.CPUShares
	}
	if service.CPUQuota > 0 {
		data["cpu_quota"] = service.CPUQuota
	}
	if service.MemoryLimit != "" {
		data["mem_limit"] = service.MemoryLimit
	}
	if service.MemorySwap != "" {
		data["memswap_limit"] = service.MemorySwap
	}

	// Healthcheck
	if service.HealthCheck != nil {
		hc := make(map[string]interface{})
		if len(service.HealthCheck.Test) > 0 {
			hc["test"] = service.HealthCheck.Test
		}
		if service.HealthCheck.Interval != "" {
			hc["interval"] = service.HealthCheck.Interval
		}
		if service.HealthCheck.Timeout != "" {
			hc["timeout"] = service.HealthCheck.Timeout
		}
		if service.HealthCheck.Retries > 0 {
			hc["retries"] = service.HealthCheck.Retries
		}
		if service.HealthCheck.StartPeriod != "" {
			hc["start_period"] = service.HealthCheck.StartPeriod
		}
		data["healthcheck"] = hc
	}

	// Labels
	if len(service.Labels) > 0 {
		data["labels"] = service.Labels
	}

	// Extensions
	for key, value := range service.Extensions {
		data[key] = value
	}

	return data, nil
}

func serializeNetwork(network *Network) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	if network.Driver != "" {
		data["driver"] = network.Driver
	}
	if len(network.DriverOpts) > 0 {
		data["driver_opts"] = network.DriverOpts
	}
	if network.Attachable {
		data["attachable"] = true
	}
	if network.External {
		data["external"] = true
	}
	if network.Internal {
		data["internal"] = true
	}
	if network.IPAM != nil {
		ipamData := make(map[string]interface{})
		if network.IPAM.Driver != "" {
			ipamData["driver"] = network.IPAM.Driver
		}
		if len(network.IPAM.Config) > 0 {
			var config []map[string]interface{}
			for _, subnet := range network.IPAM.Config {
				subnetData := make(map[string]interface{})
				if subnet.Subnet != "" {
					subnetData["subnet"] = subnet.Subnet
				}
				if subnet.Gateway != "" {
					subnetData["gateway"] = subnet.Gateway
				}
				config = append(config, subnetData)
			}
			ipamData["config"] = config
		}
		if len(network.IPAM.Options) > 0 {
			ipamData["options"] = network.IPAM.Options
		}
		data["ipam"] = ipamData
	}
	if len(network.Labels) > 0 {
		data["labels"] = network.Labels
	}

	return data, nil
}

func serializeVolume(volume *Volume) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	if volume.Driver != "" {
		data["driver"] = volume.Driver
	}
	if len(volume.DriverOpts) > 0 {
		data["driver_opts"] = volume.DriverOpts
	}
	if volume.External {
		data["external"] = true
	}
	if len(volume.Labels) > 0 {
		data["labels"] = volume.Labels
	}

	return data, nil
}

func serializeConfig(config *Config) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	if config.Content != "" {
		data["content"] = config.Content
	}
	if config.File != "" {
		data["file"] = config.File
	}
	if config.Template != "" {
		data["template"] = config.Template
	}
	if config.Mode != "" {
		data["mode"] = config.Mode
	}

	return data, nil
}

func serializeSecret(secret *Secret) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	if secret.File != "" {
		data["file"] = secret.File
	}
	if secret.Environment != "" {
		data["environment"] = secret.Environment
	}
	if secret.External {
		data["external"] = true
	}

	return data, nil
}