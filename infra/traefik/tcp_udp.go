package traefik

import (
	"fmt"
	"strconv"
	"strings"

	"cluster/infra/cluster/gossip"
)

// computeTCPConfig computes TCP routers and services from gossip state
func (s *HTTPProviderServer) computeTCPConfig() *TCPConfig {
	config := &TCPConfig{
		Routers:  make(map[string]*TCPRouter),
		Services: make(map[string]*TCPService),
	}

	// Get all service health entries
	serviceHealthMap := s.gossipState.GetAllServiceHealth()

	// Group services by name
	allServices := make(map[string][]*gossip.ServiceHealth)
	for key, health := range serviceHealthMap {
		parts := strings.Split(key, "@")
		if len(parts) != 2 {
			continue
		}
		serviceName := parts[0]

		// Only include services that have TCP endpoints
		if _, hasTCP := health.Endpoints["tcp"]; hasTCP || isTCPService(serviceName) {
			if allServices[serviceName] == nil {
				allServices[serviceName] = make([]*gossip.ServiceHealth, 0)
			}
			allServices[serviceName] = append(allServices[serviceName], health)
		}
	}

	// For each TCP service, create routers and services
	for serviceName, healthEntries := range allServices {
		// Filter to only healthy services
		healthyEntries := make([]*gossip.ServiceHealth, 0)
		for _, health := range healthEntries {
			if health.Healthy {
				healthyEntries = append(healthyEntries, health)
			}
		}

		if len(healthyEntries) == 0 {
			continue
		}

		// Get TCP port from endpoints or default
		tcpPort := getTCPPort(healthyEntries[0])

		// Create direct router: <service>.<node>.domain
		for _, health := range healthyEntries {
			routerName := fmt.Sprintf("%s-%s-tcp-direct", serviceName, health.NodeName)
			serviceNameDirect := fmt.Sprintf("%s-%s-tcp-direct", serviceName, health.NodeName)

			// Create router rule using HostSNI for TLS passthrough
			rule := fmt.Sprintf("HostSNI(`%s.%s.%s`) || HostSNI(`%s.%s`)", serviceName, health.NodeName, s.domain, serviceName, s.domain)

			config.Routers[routerName] = &TCPRouter{
				Rule:        rule,
				Service:     serviceNameDirect,
				EntryPoints: []string{"websecure"},
				TLS: &TLS{
					CertResolver: "letsencrypt",
				},
			}

			// Create direct TCP service
			tcpEndpoint := health.Endpoints["tcp"]
			if tcpEndpoint == "" {
				// Construct from service name and port
				tcpEndpoint = fmt.Sprintf("%s:%d", serviceName, tcpPort)
			}

			// Parse address:port
			address := parseTCPAddress(tcpEndpoint)

			config.Services[serviceNameDirect] = &TCPService{
				LoadBalancer: &TCPLoadBalancer{
					Servers: []TCPServer{
						{Address: address},
					},
				},
			}
		}

		// Create load-balanced router: <service>.domain (with failover)
		if len(healthyEntries) > 0 {
			routerName := fmt.Sprintf("%s-tcp-with-failover", serviceName)
			serviceNameFailover := fmt.Sprintf("%s-tcp-with-failover", serviceName)

			rule := fmt.Sprintf("HostSNI(`%s.%s`)", serviceName, s.domain)

			config.Routers[routerName] = &TCPRouter{
				Rule:        rule,
				Service:     serviceNameFailover,
				EntryPoints: []string{"websecure"},
				TLS: &TLS{
					CertResolver: "letsencrypt",
				},
			}

			// Create failover TCP service with all healthy backends
			servers := make([]TCPServer, 0, len(healthyEntries))
			for _, health := range healthyEntries {
				tcpEndpoint := health.Endpoints["tcp"]
				if tcpEndpoint == "" {
					// For cross-node access, we'd use Tailscale IPs or node-specific domains
					// For now, use service name (assuming same network)
					tcpEndpoint = fmt.Sprintf("%s:%d", serviceName, tcpPort)
				}

				address := parseTCPAddress(tcpEndpoint)
				servers = append(servers, TCPServer{Address: address})
			}

			config.Services[serviceNameFailover] = &TCPService{
				LoadBalancer: &TCPLoadBalancer{
					Servers: servers,
				},
			}
		}
	}

	return config
}

// computeUDPConfig computes UDP routers and services from gossip state
func (s *HTTPProviderServer) computeUDPConfig() *UDPConfig {
	config := &UDPConfig{
		Routers:  make(map[string]*UDPRouter),
		Services: make(map[string]*UDPService),
	}

	// Get all service health entries
	serviceHealthMap := s.gossipState.GetAllServiceHealth()

	// Group services by name
	allServices := make(map[string][]*gossip.ServiceHealth)
	for key, health := range serviceHealthMap {
		parts := strings.Split(key, "@")
		if len(parts) != 2 {
			continue
		}
		serviceName := parts[0]

		// Only include services that have UDP endpoints
		if _, hasUDP := health.Endpoints["udp"]; hasUDP || isUDPService(serviceName) {
			if allServices[serviceName] == nil {
				allServices[serviceName] = make([]*gossip.ServiceHealth, 0)
			}
			allServices[serviceName] = append(allServices[serviceName], health)
		}
	}

	// For each UDP service, create routers and services
	for serviceName, healthEntries := range allServices {
		// Filter to only healthy services
		healthyEntries := make([]*gossip.ServiceHealth, 0)
		for _, health := range healthEntries {
			if health.Healthy {
				healthyEntries = append(healthyEntries, health)
			}
		}

		if len(healthyEntries) == 0 {
			continue
		}

		// Get UDP port from endpoints or default
		udpPort := getUDPPort(healthyEntries[0])

		// Create UDP router
		routerName := fmt.Sprintf("%s-udp", serviceName)
		serviceNameUDP := fmt.Sprintf("%s-udp", serviceName)

		config.Routers[routerName] = &UDPRouter{
			EntryPoints: []string{"websecure"},
			Service:     serviceNameUDP,
		}

		// Create UDP service with all healthy backends
		servers := make([]UDPServer, 0, len(healthyEntries))
		for _, health := range healthyEntries {
			udpEndpoint := health.Endpoints["udp"]
			if udpEndpoint == "" {
				udpEndpoint = fmt.Sprintf("%s:%d", serviceName, udpPort)
			}

			address := parseUDPAddress(udpEndpoint)
			servers = append(servers, UDPServer{Address: address})
		}

		config.Services[serviceNameUDP] = &UDPService{
			LoadBalancer: &UDPLoadBalancer{
				Servers: servers,
			},
		}
	}

	return config
}

// Helper functions

// isTCPService checks if a service is known to be a TCP service
func isTCPService(serviceName string) bool {
	tcpServices := []string{"mongodb", "redis", "postgres", "mysql"}
	for _, name := range tcpServices {
		if strings.Contains(strings.ToLower(serviceName), name) {
			return true
		}
	}
	return false
}

// isUDPService checks if a service is known to be a UDP service
func isUDPService(serviceName string) bool {
	udpServices := []string{"dns", "ntp"}
	for _, name := range udpServices {
		if strings.Contains(strings.ToLower(serviceName), name) {
			return true
		}
	}
	return false
}

// getTCPPort extracts TCP port from service health or returns default
func getTCPPort(health *gossip.ServiceHealth) int {
	if tcpEndpoint, ok := health.Endpoints["tcp"]; ok {
		if port := parsePort(tcpEndpoint); port > 0 {
			return port
		}
	}

	// Default ports for common services
	defaultPorts := map[string]int{
		"mongodb":  27017,
		"redis":    6379,
		"postgres": 5432,
		"mysql":    3306,
	}

	for serviceName, port := range defaultPorts {
		if strings.Contains(strings.ToLower(health.ServiceName), serviceName) {
			return port
		}
	}

	return 8080 // Default fallback
}

// getUDPPort extracts UDP port from service health or returns default
func getUDPPort(health *gossip.ServiceHealth) int {
	if udpEndpoint, ok := health.Endpoints["udp"]; ok {
		if port := parsePort(udpEndpoint); port > 0 {
			return port
		}
	}

	return 53 // Default DNS port
}

// parsePort extracts port number from address:port string
func parsePort(address string) int {
	parts := strings.Split(address, ":")
	if len(parts) < 2 {
		return 0
	}

	port, err := strconv.Atoi(parts[len(parts)-1])
	if err != nil {
		return 0
	}

	return port
}

// parseTCPAddress parses TCP address from endpoint string
func parseTCPAddress(endpoint string) string {
	// Remove protocol prefix if present
	endpoint = strings.TrimPrefix(endpoint, "tcp://")
	endpoint = strings.TrimPrefix(endpoint, "tcp:")

	// If no port specified, add default
	if !strings.Contains(endpoint, ":") {
		return endpoint + ":8080"
	}

	return endpoint
}

// parseUDPAddress parses UDP address from endpoint string
func parseUDPAddress(endpoint string) string {
	// Remove protocol prefix if present
	endpoint = strings.TrimPrefix(endpoint, "udp://")
	endpoint = strings.TrimPrefix(endpoint, "udp:")

	// If no port specified, add default
	if !strings.Contains(endpoint, ":") {
		return endpoint + ":53"
	}

	return endpoint
}
