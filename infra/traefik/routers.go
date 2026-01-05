package traefik

import (
	"fmt"
	"strings"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
)

// computeHTTPConfig computes HTTP/HTTPS routers and services from gossip state
func (s *HTTPProviderServer) computeHTTPConfig() *HTTPConfig {
	config := &HTTPConfig{
		Routers:     make(map[string]*Router),
		Services:    make(map[string]*Service),
		Middlewares: make(map[string]*Middleware),
	}

	// Get all service health entries from gossip state

	// Get all service health entries
	allServices := make(map[string][]*gossip.ServiceHealth) // service name -> health entries

	// Iterate through all service health entries
	// Note: We need to access the internal state to iterate - we'll add a helper method
	serviceHealthMap := s.gossipState.GetAllServiceHealth()

	for key, health := range serviceHealthMap {
		// Key format is "service@node"
		parts := strings.Split(key, "@")
		if len(parts) != 2 {
			continue
		}
		serviceName := parts[0]

		if allServices[serviceName] == nil {
			allServices[serviceName] = make([]*gossip.ServiceHealth, 0)
		}
		allServices[serviceName] = append(allServices[serviceName], health)
	}

	// For each service, create routers and services
	for serviceName, healthEntries := range allServices {
		// Filter to only healthy services
		healthyEntries := make([]*gossip.ServiceHealth, 0)
		for _, health := range healthEntries {
			if health.Healthy {
				healthyEntries = append(healthyEntries, health)
			}
		}

		if len(healthyEntries) == 0 {
			continue // Skip services with no healthy instances
		}

		// Create direct router: <service>.<node>.domain
		for _, health := range healthyEntries {
			routerName := fmt.Sprintf("%s-%s-direct", serviceName, health.NodeName)
			serviceNameDirect := fmt.Sprintf("%s-%s-direct", serviceName, health.NodeName)

			// Create router rule
			rule := fmt.Sprintf("Host(`%s.%s.%s`)", serviceName, health.NodeName, s.domain)

			config.Routers[routerName] = &Router{
				Rule:        rule,
				Service:     serviceNameDirect,
				EntryPoints: []string{"websecure"},
				TLS: &TLS{
					CertResolver: "letsencrypt",
				},
			}

			// Create direct service (points to local service)
			httpEndpoint := health.Endpoints["http"]
			if httpEndpoint == "" {
				// Fallback: construct from service name
				httpEndpoint = fmt.Sprintf("http://%s:8080", serviceName)
			}

			config.Services[serviceNameDirect] = &Service{
				LoadBalancer: &LoadBalancer{
					Servers: []Server{
						{URL: httpEndpoint},
					},
				},
			}
		}

		// Create load-balanced router: <service>.domain (with failover)
		if len(healthyEntries) > 0 {
			routerName := fmt.Sprintf("%s-with-failover", serviceName)
			serviceNameFailover := fmt.Sprintf("%s-with-failover", serviceName)

			rule := fmt.Sprintf("Host(`%s.%s`)", serviceName, s.domain)

			config.Routers[routerName] = &Router{
				Rule:        rule,
				Service:     serviceNameFailover,
				EntryPoints: []string{"websecure"},
				TLS: &TLS{
					CertResolver: "letsencrypt",
				},
			}

			// Create failover service with all healthy backends
			servers := make([]Server, 0, len(healthyEntries))
			for _, health := range healthyEntries {
				httpEndpoint := health.Endpoints["http"]
				if httpEndpoint == "" {
					// Construct endpoint from service name and node
					// For cross-node access, use the node-specific domain
					httpEndpoint = fmt.Sprintf("https://%s.%s.%s", serviceName, health.NodeName, s.domain)
				}
				servers = append(servers, Server{URL: httpEndpoint})
			}

			// Get health check config from first healthy entry (they should be similar)
			var healthCheck *HealthCheck
			if len(healthyEntries) > 0 {
				// Extract health check path from labels or use default
				healthCheck = &HealthCheck{
					Path:     "/",
					Interval: "30s",
					Timeout:  "10s",
				}
			}

			config.Services[serviceNameFailover] = &Service{
				LoadBalancer: &LoadBalancer{
					Servers:     servers,
					HealthCheck: healthCheck,
					Method:      "wrr", // Weighted round robin
				},
			}
		}
	}

	// Generate common middlewares
	s.generateCommonMiddlewares(config)

	return config
}

// generateCommonMiddlewares generates common middleware configurations
func (s *HTTPProviderServer) generateCommonMiddlewares(config *HTTPConfig) {
	// Add compression middleware (commonly used)
	config.Middlewares["compress"] = &Middleware{
		Compress: &CompressMiddleware{
			ExcludedContentTypes: []string{
				"text/event-stream",
				"application/octet-stream",
			},
		},
	}

	// Add security headers middleware
	config.Middlewares["security-headers"] = &Middleware{
		Headers: &HeadersMiddleware{
			CustomResponseHeaders: map[string]string{
				"X-Content-Type-Options":    "nosniff",
				"X-Frame-Options":           "DENY",
				"X-XSS-Protection":          "1; mode=block",
				"Strict-Transport-Security": "max-age=31536000; includeSubDomains",
				"Content-Security-Policy":   "default-src 'self'",
				"Referrer-Policy":           "strict-origin-when-cross-origin",
			},
		},
	}

	// Add CORS middleware (if needed)
	config.Middlewares["cors"] = &Middleware{
		Headers: &HeadersMiddleware{
			AccessControlAllowMethods:    []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
			AccessControlAllowOriginList: []string{"*"},
			AccessControlMaxAge:          3600,
			AddVaryHeader:                true,
		},
	}
}
