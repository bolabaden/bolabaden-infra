package traefik

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
)

// HTTPProviderServer serves Traefik dynamic configuration via HTTP provider API
type HTTPProviderServer struct {
	gossipState   *gossip.ClusterState
	port          int
	domain        string
	localNodeName string
	server        *http.Server
	mu            sync.RWMutex
	lastConfig    *TraefikDynamicConfig
	lastUpdate    time.Time
}

// TraefikDynamicConfig represents the Traefik dynamic configuration format
type TraefikDynamicConfig struct {
	HTTP *HTTPConfig `json:"http,omitempty"`
	TCP  *TCPConfig  `json:"tcp,omitempty"`
	UDP  *UDPConfig  `json:"udp,omitempty"`
}

// HTTPConfig contains HTTP/HTTPS routers, services, and middlewares
type HTTPConfig struct {
	Routers     map[string]*Router     `json:"routers,omitempty"`
	Services    map[string]*Service    `json:"services,omitempty"`
	Middlewares map[string]*Middleware `json:"middlewares,omitempty"`
}

// TCPConfig contains TCP routers and services
type TCPConfig struct {
	Routers  map[string]*TCPRouter  `json:"routers,omitempty"`
	Services map[string]*TCPService `json:"services,omitempty"`
}

// UDPConfig contains UDP routers and services
type UDPConfig struct {
	Routers  map[string]*UDPRouter  `json:"routers,omitempty"`
	Services map[string]*UDPService `json:"services,omitempty"`
}

// Router represents an HTTP router
type Router struct {
	Rule        string   `json:"rule"`
	Service     string   `json:"service"`
	EntryPoints []string `json:"entryPoints,omitempty"`
	TLS         *TLS     `json:"tls,omitempty"`
	Middlewares []string `json:"middlewares,omitempty"`
	Priority    int      `json:"priority,omitempty"`
}

// Service represents an HTTP service
type Service struct {
	LoadBalancer *LoadBalancer `json:"loadBalancer,omitempty"`
}

// LoadBalancer represents a load balancer configuration
type LoadBalancer struct {
	Servers     []Server      `json:"servers"`
	HealthCheck *HealthCheck  `json:"healthCheck,omitempty"`
	Method      string        `json:"method,omitempty"`
	Sticky      *StickyCookie `json:"sticky,omitempty"`
}

// Server represents a backend server
type Server struct {
	URL string `json:"url"`
}

// HealthCheck represents a health check configuration
type HealthCheck struct {
	Path     string `json:"path,omitempty"`
	Interval string `json:"interval,omitempty"`
	Timeout  string `json:"timeout,omitempty"`
}

// TLS represents TLS configuration
type TLS struct {
	CertResolver string   `json:"certResolver,omitempty"`
	Domains      []Domain `json:"domains,omitempty"`
}

// Domain represents a TLS domain
type Domain struct {
	Main string   `json:"main,omitempty"`
	SANs []string `json:"sans,omitempty"`
}

// Middleware represents a middleware configuration
type Middleware struct {
	// Middleware configuration varies by type
	// This is a placeholder - actual middleware configs will be added as needed
}

// StickyCookie represents sticky session configuration
type StickyCookie struct {
	Name     string `json:"name,omitempty"`
	Secure   bool   `json:"secure,omitempty"`
	HTTPOnly bool   `json:"httpOnly,omitempty"`
	SameSite string `json:"sameSite,omitempty"`
}

// TCPRouter represents a TCP router
type TCPRouter struct {
	Rule        string   `json:"rule"`
	Service     string   `json:"service"`
	EntryPoints []string `json:"entryPoints,omitempty"`
	TLS         *TLS     `json:"tls,omitempty"`
}

// TCPService represents a TCP service
type TCPService struct {
	LoadBalancer *TCPLoadBalancer `json:"loadBalancer,omitempty"`
}

// TCPLoadBalancer represents a TCP load balancer
type TCPLoadBalancer struct {
	Servers []TCPServer `json:"servers"`
}

// TCPServer represents a TCP backend server
type TCPServer struct {
	Address string `json:"address"`
}

// UDPRouter represents a UDP router
type UDPRouter struct {
	EntryPoints []string `json:"entryPoints,omitempty"`
	Service     string   `json:"service"`
}

// UDPService represents a UDP service
type UDPService struct {
	LoadBalancer *UDPLoadBalancer `json:"loadBalancer,omitempty"`
}

// UDPLoadBalancer represents a UDP load balancer
type UDPLoadBalancer struct {
	Servers []UDPServer `json:"servers"`
}

// UDPServer represents a UDP backend server
type UDPServer struct {
	Address string `json:"address"`
}

// NewHTTPProviderServer creates a new HTTP provider server
func NewHTTPProviderServer(gossipState *gossip.ClusterState, port int, domain, localNodeName string) *HTTPProviderServer {
	return &HTTPProviderServer{
		gossipState:   gossipState,
		port:          port,
		domain:        domain,
		localNodeName: localNodeName,
	}
}

// Start starts the HTTP provider server
func (s *HTTPProviderServer) Start() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/dynamic", s.handleDynamicConfig)
	mux.HandleFunc("/health", s.handleHealth)

	s.server = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("Starting Traefik HTTP provider server on :%d", s.port)
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *HTTPProviderServer) Shutdown() error {
	if s.server == nil {
		return nil
	}
	return s.server.Close()
}

// handleDynamicConfig handles requests for dynamic configuration
func (s *HTTPProviderServer) handleDynamicConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Compute config from gossip state
	config := s.computeConfig()

	// Set headers
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	// Marshal and write response
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(config); err != nil {
		log.Printf("Failed to encode Traefik config: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}

// handleHealth handles health check requests
func (s *HTTPProviderServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

// computeConfig computes the Traefik dynamic configuration from gossip state
func (s *HTTPProviderServer) computeConfig() *TraefikDynamicConfig {
	// Check if we have a recent cached config
	s.mu.RLock()
	if s.lastConfig != nil && time.Since(s.lastUpdate) < 5*time.Second {
		config := s.lastConfig
		s.mu.RUnlock()
		return config
	}
	s.mu.RUnlock()

	// Compute new config
	config := &TraefikDynamicConfig{
		HTTP: s.computeHTTPConfig(),
		TCP:  s.computeTCPConfig(),
		UDP:  s.computeUDPConfig(),
	}

	// Cache the config
	s.mu.Lock()
	s.lastConfig = config
	s.lastUpdate = time.Now()
	s.mu.Unlock()

	return config
}

// computeHTTPConfig is implemented in routers.go
// computeTCPConfig and computeUDPConfig are implemented in tcp_udp.go
