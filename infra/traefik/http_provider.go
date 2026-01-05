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
	// Common middleware types
	BasicAuth   *BasicAuthMiddleware   `json:"basicAuth,omitempty"`
	Headers     *HeadersMiddleware     `json:"headers,omitempty"`
	Redirect    *RedirectMiddleware    `json:"redirect,omitempty"`
	StripPrefix *StripPrefixMiddleware `json:"stripPrefix,omitempty"`
	RateLimit   *RateLimitMiddleware   `json:"rateLimit,omitempty"`
	Compress    *CompressMiddleware    `json:"compress,omitempty"`
}

// BasicAuthMiddleware represents basic authentication middleware
type BasicAuthMiddleware struct {
	Users        []string `json:"users,omitempty"`
	UsersFile    string   `json:"usersFile,omitempty"`
	Realm        string   `json:"realm,omitempty"`
	RemoveHeader bool     `json:"removeHeader,omitempty"`
	HeaderField  string   `json:"headerField,omitempty"`
}

// HeadersMiddleware represents headers middleware
type HeadersMiddleware struct {
	CustomRequestHeaders         map[string]string `json:"customRequestHeaders,omitempty"`
	CustomResponseHeaders        map[string]string `json:"customResponseHeaders,omitempty"`
	AccessControlAllowMethods    []string          `json:"accessControlAllowMethods,omitempty"`
	AccessControlAllowOriginList []string          `json:"accessControlAllowOriginList,omitempty"`
	AccessControlMaxAge          int               `json:"accessControlMaxAge,omitempty"`
	AddVaryHeader                bool              `json:"addVaryHeader,omitempty"`
}

// RedirectMiddleware represents redirect middleware
type RedirectMiddleware struct {
	Scheme    string `json:"scheme,omitempty"`
	Permanent bool   `json:"permanent,omitempty"`
	Port      string `json:"port,omitempty"`
}

// StripPrefixMiddleware represents strip prefix middleware
type StripPrefixMiddleware struct {
	Prefixes []string `json:"prefixes,omitempty"`
}

// RateLimitMiddleware represents rate limit middleware
type RateLimitMiddleware struct {
	Average int    `json:"average,omitempty"`
	Period  string `json:"period,omitempty"`
	Burst   int    `json:"burst,omitempty"`
}

// CompressMiddleware represents compression middleware
type CompressMiddleware struct {
	ExcludedContentTypes []string `json:"excludedContentTypes,omitempty"`
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

	// Traefik HTTP provider standard endpoints
	mux.HandleFunc("/api/http/routers", s.handleHTTPRouters)
	mux.HandleFunc("/api/http/services", s.handleHTTPServices)
	mux.HandleFunc("/api/http/middlewares", s.handleHTTPMiddlewares)
	mux.HandleFunc("/api/tcp/routers", s.handleTCPRouters)
	mux.HandleFunc("/api/tcp/services", s.handleTCPServices)
	mux.HandleFunc("/api/udp/routers", s.handleUDPRouters)
	mux.HandleFunc("/api/udp/services", s.handleUDPServices)

	// Legacy single endpoint (for compatibility)
	mux.HandleFunc("/api/dynamic", s.handleDynamicConfig)

	// Health check
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

// handleDynamicConfig handles requests for dynamic configuration (legacy endpoint)
func (s *HTTPProviderServer) handleDynamicConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Compute config from gossip state
	config := s.computeConfig()
	s.writeJSON(w, config)
}

// handleHealth handles health check requests
func (s *HTTPProviderServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

// handleHTTPRouters handles requests for HTTP routers
func (s *HTTPProviderServer) handleHTTPRouters(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.HTTP == nil || config.HTTP.Routers == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.HTTP.Routers)
}

// handleHTTPServices handles requests for HTTP services
func (s *HTTPProviderServer) handleHTTPServices(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.HTTP == nil || config.HTTP.Services == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.HTTP.Services)
}

// handleHTTPMiddlewares handles requests for HTTP middlewares
func (s *HTTPProviderServer) handleHTTPMiddlewares(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.HTTP == nil || config.HTTP.Middlewares == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.HTTP.Middlewares)
}

// handleTCPRouters handles requests for TCP routers
func (s *HTTPProviderServer) handleTCPRouters(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.TCP == nil || config.TCP.Routers == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.TCP.Routers)
}

// handleTCPServices handles requests for TCP services
func (s *HTTPProviderServer) handleTCPServices(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.TCP == nil || config.TCP.Services == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.TCP.Services)
}

// handleUDPRouters handles requests for UDP routers
func (s *HTTPProviderServer) handleUDPRouters(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.UDP == nil || config.UDP.Routers == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.UDP.Routers)
}

// handleUDPServices handles requests for UDP services
func (s *HTTPProviderServer) handleUDPServices(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	config := s.computeConfig()
	if config.UDP == nil || config.UDP.Services == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("{}"))
		return
	}

	s.writeJSON(w, config.UDP.Services)
}

// writeJSON writes a JSON response
func (s *HTTPProviderServer) writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		log.Printf("Failed to encode JSON response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
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
