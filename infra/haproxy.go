package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/docker/docker/api/types"
)

// GenerateHAProxyConfig generates HAProxy configuration for L4 load balancing
func GenerateHAProxyConfig(config *Config, nodes []TailscaleNode) error {
	// Discover L4 services from Docker containers
	services, err := discoverL4Services()
	if err != nil {
		return fmt.Errorf("failed to discover L4 services: %w", err)
	}

	if len(services) == 0 {
		return nil // No L4 services, skip config generation
	}

	// Build node IP map
	nodeIPs := make(map[string]string)
	for _, node := range nodes {
		nodeIPs[node.Name] = node.TailscaleIP
	}

	// Generate HAProxy config
	lines := []string{
		"global",
		"  log stdout format raw local0",
		"  maxconn 20000",
		"",
		"defaults",
		"  log global",
		"  mode tcp",
		"  option tcplog",
		"  timeout connect 5s",
		"  timeout client  1m",
		"  timeout server  1m",
		"",
		"listen stats",
		"  bind 0.0.0.0:8404",
		"  mode http",
		"  stats enable",
		"  stats uri /",
		"",
	}

	// Sort services by port for stable output
	sort.Slice(services, func(i, j int) bool {
		return services[i].Port < services[j].Port
	})

	for _, svc := range services {
		port := svc.Port
		lines = append(lines, fmt.Sprintf("frontend fe_%d", port))
		lines = append(lines, fmt.Sprintf("  bind 0.0.0.0:%d", port))
		lines = append(lines, fmt.Sprintf("  default_backend be_%d", port))
		lines = append(lines, "")

		lines = append(lines, fmt.Sprintf("backend be_%d", port))
		lines = append(lines, "  mode tcp")

		// Healthcheck based on service type
		if svc.Check == "redis" {
			lines = append(lines, "  option tcp-check")
			lines = append(lines, "  tcp-check connect")
			lines = append(lines, "  tcp-check send PING\\r\\n")
			lines = append(lines, "  tcp-check expect string +PONG")
		} else {
			lines = append(lines, "  option tcp-check")
			lines = append(lines, "  tcp-check connect")
		}

		lines = append(lines, "  balance leastconn")

		// Add backend servers using Tailscale IPs
		sortedNodes := make([]TailscaleNode, len(nodes))
		copy(sortedNodes, nodes)
		sort.Slice(sortedNodes, func(i, j int) bool {
			return sortedNodes[i].Priority < sortedNodes[j].Priority
		})

		for _, node := range sortedNodes {
			target := fmt.Sprintf("%s:%d", node.TailscaleIP, port)
			lines = append(lines, fmt.Sprintf("  server %s_%s %s check inter 3s fall 3 rise 2", svc.Name, node.Name, target))
		}
		lines = append(lines, "")
	}

	content := strings.Join(lines, "\n") + "\n"

	// Write to file
	outputPath := filepath.Join(config.ConfigPath, "haproxy", "haproxy.cfg")
	if err := os.MkdirAll(filepath.Dir(outputPath), 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	if err := atomicWrite(outputPath, content); err != nil {
		return fmt.Errorf("failed to write config: %w", err)
	}

	return nil
}

// L4Service represents a TCP service for L4 load balancing
type L4Service struct {
	Name  string
	Port  int
	Check string // "tcp" or "redis"
}

// discoverL4Services discovers containers with osvc.l4.enable=true
// This is a helper that creates a temporary infra instance
func discoverL4Services() ([]L4Service, error) {
	config := loadConfig()
	infra, err := NewInfrastructure(config)
	if err != nil {
		return nil, err
	}
	defer infra.client.Close()
	return infra.DiscoverL4ServicesFromDocker()
}

// DiscoverL4ServicesFromDocker discovers L4 services from Docker containers
func (infra *Infrastructure) DiscoverL4ServicesFromDocker() ([]L4Service, error) {
	containers, err := infra.client.ContainerList(infra.ctx, types.ContainerListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list containers: %w", err)
	}

	services := []L4Service{}
	portMap := make(map[int]L4Service) // Deduplicate by port

	for _, c := range containers {
		inspect, err := infra.client.ContainerInspect(infra.ctx, c.ID)
		if err != nil {
			continue
		}

		labels := inspect.Config.Labels
		if labels["osvc.l4.enable"] != "true" {
			continue
		}

		portStr := labels["osvc.l4.port"]
		if portStr == "" {
			continue
		}

		port := parseInt(portStr)
		if port == 0 {
			continue
		}

		check := labels["osvc.l4.check"]
		if check == "" {
			check = "tcp"
		}
		if check != "tcp" && check != "redis" {
			check = "tcp"
		}

		name := strings.TrimPrefix(c.Names[0], "/")

		// Only keep first service per port
		if _, exists := portMap[port]; !exists {
			portMap[port] = L4Service{
				Name:  name,
				Port:  port,
				Check: check,
			}
		}
	}

	for _, svc := range portMap {
		services = append(services, svc)
	}

	return services, nil
}
