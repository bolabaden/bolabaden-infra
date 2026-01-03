package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/docker/docker/api/types"
)

// TraefikDynamicConfig generates dynamic Traefik configuration
type TraefikDynamicConfig struct {
	config *Config
	nodes  []TailscaleNode
}

// TraefikConfig represents the complete Traefik dynamic configuration structure
type TraefikConfig struct {
	HTTP *TraefikHTTPConfig `json:"http,omitempty"`
}

type TraefikHTTPConfig struct {
	Routers  map[string]*TraefikRouter  `json:"routers,omitempty"`
	Services map[string]*TraefikService `json:"services,omitempty"`
}

type TraefikRouter struct {
	Service string `json:"service"`
	Rule    string `json:"rule"`
}

type TraefikService struct {
	LoadBalancer *TraefikLoadBalancer `json:"loadBalancer"`
}

type TraefikLoadBalancer struct {
	Servers     []TraefikServer     `json:"servers"`
	HealthCheck *TraefikHealthCheck `json:"healthCheck,omitempty"`
}

type TraefikServer struct {
	URL string `json:"url"`
}

type TraefikHealthCheck struct {
	Path     string `json:"path"`
	Interval string `json:"interval"`
	Timeout  string `json:"timeout"`
}

// GenerateFailoverConfig generates the failover-fallbacks.json for Traefik using pure Go structs
func (t *TraefikDynamicConfig) GenerateFailoverConfig(containers []ContainerInfo) error {
	domain := t.config.Domain
	localNode := getEnv("TS_HOSTNAME", "")
	if localNode == "" {
		// Fallback to hostname
		hostname, _ := os.Hostname()
		localNode = strings.Split(hostname, ".")[0]
	}

	// Build configuration using Go structs
	config := &TraefikConfig{
		HTTP: &TraefikHTTPConfig{
			Routers:  make(map[string]*TraefikRouter),
			Services: make(map[string]*TraefikService),
		},
	}

	// Generate routers and services
	for _, c := range containers {
		name := c.Name
		port := c.Port
		if port == 0 {
			continue // Skip if no port
		}

		healthPath := c.Labels["kuma.healthcheck.path"]
		if healthPath == "" {
			healthPath = "/"
		}
		healthInterval := c.Labels["kuma.healthcheck.interval"]
		if healthInterval == "" {
			healthInterval = "30s"
		}
		healthTimeout := c.Labels["kuma.healthcheck.timeout"]
		if healthTimeout == "" {
			healthTimeout = "10s"
		}

		// Direct router (node-specific)
		config.HTTP.Routers[name+"-direct"] = &TraefikRouter{
			Service: name + "-direct@file",
			Rule:    fmt.Sprintf("Host(`%s.%s.%s`)", name, localNode, domain),
		}

		// Failover router (global)
		config.HTTP.Routers[name+"-with-failover"] = &TraefikRouter{
			Service: name + "-with-failover@file",
			Rule:    fmt.Sprintf("Host(`%s.%s`)", name, domain),
		}

		// Direct service (node-specific)
		config.HTTP.Services[name+"-direct"] = &TraefikService{
			LoadBalancer: &TraefikLoadBalancer{
				Servers: []TraefikServer{
					{URL: fmt.Sprintf("http://%s:%d", name, port)},
				},
			},
		}

		// Failover service (global with fallback)
		servers := []TraefikServer{
			{URL: fmt.Sprintf("http://%s:%d", name, port)}, // Local first
		}
		// Add remote nodes
		for _, node := range t.nodes {
			if node.Name == localNode {
				continue
			}
			servers = append(servers, TraefikServer{
				URL: fmt.Sprintf("https://%s.%s.%s", name, node.Name, domain),
			})
		}

		config.HTTP.Services[name+"-with-failover"] = &TraefikService{
			LoadBalancer: &TraefikLoadBalancer{
				Servers: servers,
				HealthCheck: &TraefikHealthCheck{
					Path:     healthPath,
					Interval: healthInterval,
					Timeout:  healthTimeout,
				},
			},
		}
	}

	// Marshal to JSON
	jsonBytes, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	// Write to file
	outputPath := filepath.Join(t.config.ConfigPath, "traefik", "dynamic", "failover-fallbacks.json")
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	if err := atomicWrite(outputPath, string(jsonBytes)+"\n"); err != nil {
		return fmt.Errorf("failed to write config: %w", err)
	}

	return nil
}

// ContainerInfo represents a discovered container
type ContainerInfo struct {
	Name   string
	Port   int
	Labels map[string]string
}

// DiscoverTraefikContainers discovers containers with traefik.enable=true
func (infra *Infrastructure) DiscoverTraefikContainers() ([]ContainerInfo, error) {
	containers, err := infra.client.ContainerList(infra.ctx, types.ContainerListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list containers: %w", err)
	}

	result := []ContainerInfo{}
	for _, c := range containers {
		// Inspect container for labels
		inspect, err := infra.client.ContainerInspect(infra.ctx, c.ID)
		if err != nil {
			continue
		}

		labels := inspect.Config.Labels
		if labels["traefik.enable"] != "true" {
			continue
		}

		// Only include HTTP services (not TCP)
		hasHTTP := false
		for k := range labels {
			if strings.HasPrefix(k, "traefik.http.") {
				hasHTTP = true
				break
			}
		}
		if !hasHTTP {
			continue
		}

		// Extract port
		port := 0
		for k, v := range labels {
			if strings.HasSuffix(k, ".loadbalancer.server.port") {
				port = parseInt(v)
				break
			}
		}

		// Extract exposed ports if no label
		if port == 0 && len(inspect.Config.ExposedPorts) > 0 {
			for p := range inspect.Config.ExposedPorts {
				portStr := strings.Split(string(p), "/")[0]
				port = parseInt(portStr)
				break
			}
		}

		if port > 0 {
			result = append(result, ContainerInfo{
				Name:   strings.TrimPrefix(c.Names[0], "/"),
				Port:   port,
				Labels: labels,
			})
		}
	}

	return result, nil
}

func parseInt(s string) int {
	var n int
	fmt.Sscanf(s, "%d", &n)
	return n
}

func atomicWrite(path, content string) error {
	tmpPath := path + ".tmp"
	if err := os.WriteFile(tmpPath, []byte(content), 0644); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}
