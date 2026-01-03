package smartproxy

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
)

// SmartProxy implements an intelligent HTTP proxy with failover capabilities
type SmartProxy struct {
	gossipState     *gossip.ClusterState
	circuitBreakers map[string]*CircuitBreaker // "service@node" -> circuit breaker
	mu              sync.RWMutex
	httpClient      *http.Client
}

// NewSmartProxy creates a new smart proxy
func NewSmartProxy(gossipState *gossip.ClusterState) *SmartProxy {
	return &SmartProxy{
		gossipState:     gossipState,
		circuitBreakers: make(map[string]*CircuitBreaker),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        100,
				MaxIdleConnsPerHost: 10,
				IdleConnTimeout:     90 * time.Second,
			},
		},
	}
}

// ServeHTTP implements http.Handler interface
func (sp *SmartProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Extract service name from Host header
	host := r.Host
	serviceName := extractServiceName(host)

	if serviceName == "" {
		http.Error(w, "Invalid service name", http.StatusBadRequest)
		return
	}

	// Get healthy backends for this service
	backends := sp.getHealthyBackends(serviceName)
	if len(backends) == 0 {
		http.Error(w, "No healthy backends available", http.StatusServiceUnavailable)
		return
	}

	// Select backend (local-first, then by priority)
	backend := sp.selectBackend(backends, serviceName)

	// Check circuit breaker
	cbKey := fmt.Sprintf("%s@%s", serviceName, backend.NodeName)
	sp.mu.RLock()
	cb, exists := sp.circuitBreakers[cbKey]
	sp.mu.RUnlock()

	if !exists {
		sp.mu.Lock()
		cb = NewCircuitBreaker(serviceName, backend.NodeName)
		sp.circuitBreakers[cbKey] = cb
		sp.mu.Unlock()
	}

	if !cb.Allow() {
		// Circuit breaker is open, try next backend
		log.Printf("Circuit breaker open for %s, trying next backend", cbKey)
		backends = removeBackend(backends, backend)
		if len(backends) == 0 {
			http.Error(w, "All backends unavailable", http.StatusServiceUnavailable)
			return
		}
		backend = sp.selectBackend(backends, serviceName)
		cbKey = fmt.Sprintf("%s@%s", serviceName, backend.NodeName)
		sp.mu.RLock()
		cb, exists = sp.circuitBreakers[cbKey]
		sp.mu.RUnlock()
		if !exists {
			sp.mu.Lock()
			cb = NewCircuitBreaker(serviceName, backend.NodeName)
			sp.circuitBreakers[cbKey] = cb
			sp.mu.Unlock()
		}
	}

	// Check if request is idempotent
	isIdempotent := sp.isIdempotentRequest(r)

	// Try the request with failover
	err := sp.proxyRequest(w, r, backend, cb, isIdempotent, backends)

	if err != nil {
		log.Printf("Proxy request failed: %v", err)
		// Error already written to response
	}
}

// proxyRequest proxies the request to a backend with failover support
func (sp *SmartProxy) proxyRequest(w http.ResponseWriter, r *http.Request, backend *Backend, cb *CircuitBreaker, isIdempotent bool, allBackends []*Backend) error {
	// Build target URL
	targetURL, err := sp.buildTargetURL(r, backend)
	if err != nil {
		http.Error(w, "Invalid target URL", http.StatusBadRequest)
		return err
	}

	// Create new request
	proxyReq, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL.String(), r.Body)
	if err != nil {
		http.Error(w, "Failed to create proxy request", http.StatusInternalServerError)
		return err
	}

	// Copy headers
	for key, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(key, value)
		}
	}

	// Set X-Forwarded-* headers
	proxyReq.Header.Set("X-Forwarded-For", r.RemoteAddr)
	proxyReq.Header.Set("X-Forwarded-Proto", getScheme(r))
	proxyReq.Header.Set("X-Forwarded-Host", r.Host)

	// Execute request
	resp, err := sp.httpClient.Do(proxyReq)
	if err != nil {
		cb.RecordFailure()
		// Try failover if idempotent
		if isIdempotent && len(allBackends) > 1 {
			return sp.failoverRequest(w, r, backend, allBackends, cb, isIdempotent)
		}
		http.Error(w, "Backend request failed", http.StatusBadGateway)
		return err
	}
	defer resp.Body.Close()

	// Check response status
	if sp.shouldFailover(resp.StatusCode, isIdempotent) {
		cb.RecordFailure()
		// Try failover
		if len(allBackends) > 1 {
			return sp.failoverRequest(w, r, backend, allBackends, cb, isIdempotent)
		}
		// No more backends, return the error response
	} else {
		cb.RecordSuccess()
	}

	// Copy response headers
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}

	// Set status code
	w.WriteHeader(resp.StatusCode)

	// Copy response body
	_, err = io.Copy(w, resp.Body)
	return err
}

// failoverRequest attempts to proxy the request to another backend
func (sp *SmartProxy) failoverRequest(w http.ResponseWriter, r *http.Request, failedBackend *Backend, allBackends []*Backend, failedCB *CircuitBreaker, isIdempotent bool) error {
	// Remove failed backend from list
	remainingBackends := removeBackend(allBackends, failedBackend)

	if len(remainingBackends) == 0 {
		http.Error(w, "No healthy backends available", http.StatusServiceUnavailable)
		return fmt.Errorf("no backends available for failover")
	}

	// Select next backend
	nextBackend := sp.selectBackend(remainingBackends, extractServiceName(r.Host))

	// Get or create circuit breaker for next backend
	cbKey := fmt.Sprintf("%s@%s", extractServiceName(r.Host), nextBackend.NodeName)
	sp.mu.RLock()
	cb, exists := sp.circuitBreakers[cbKey]
	sp.mu.RUnlock()

	if !exists {
		sp.mu.Lock()
		cb = NewCircuitBreaker(extractServiceName(r.Host), nextBackend.NodeName)
		sp.circuitBreakers[cbKey] = cb
		sp.mu.Unlock()
	}

	if !cb.Allow() {
		// Next backend also has circuit breaker open
		http.Error(w, "All backends unavailable", http.StatusServiceUnavailable)
		return fmt.Errorf("circuit breaker open for all backends")
	}

	log.Printf("Failing over from %s to %s", failedBackend.NodeName, nextBackend.NodeName)

	// Retry with next backend
	return sp.proxyRequest(w, r, nextBackend, cb, isIdempotent, remainingBackends)
}

// shouldFailover determines if a response status code should trigger failover
func (sp *SmartProxy) shouldFailover(statusCode int, isIdempotent bool) bool {
	// Always failover on these status codes
	alwaysFailover := []int{502, 503, 504}

	for _, code := range alwaysFailover {
		if statusCode == code {
			return true
		}
	}

	// For idempotent requests, also failover on 500 and 429
	if isIdempotent {
		if statusCode == 500 || statusCode == 429 {
			return true
		}
	}

	// Never failover on 401, 403 (auth issues will reproduce)
	// Never failover on 404 (not found)
	return false
}

// isIdempotentRequest checks if the request is safe to retry/failover
func (sp *SmartProxy) isIdempotentRequest(r *http.Request) bool {
	// GET, HEAD, OPTIONS are always idempotent
	idempotentMethods := []string{"GET", "HEAD", "OPTIONS"}
	for _, method := range idempotentMethods {
		if r.Method == method {
			return true
		}
	}

	// Check for Idempotency-Key header (allows safe retry of POST/PUT/PATCH/DELETE)
	if r.Header.Get("Idempotency-Key") != "" {
		return true
	}

	return false
}

// getHealthyBackends returns all healthy backends for a service
func (sp *SmartProxy) getHealthyBackends(serviceName string) []*Backend {
	healthyNodes := sp.gossipState.GetHealthyServiceNodes(serviceName)
	backends := make([]*Backend, 0, len(healthyNodes))

	for _, nodeName := range healthyNodes {
		health, exists := sp.gossipState.GetServiceHealth(serviceName, nodeName)
		if !exists || !health.Healthy {
			continue
		}

		// Get HTTP endpoint
		httpEndpoint := health.Endpoints["http"]
		if httpEndpoint == "" {
			// Construct default endpoint
			httpEndpoint = fmt.Sprintf("http://%s:8080", serviceName)
		}

		// Get node metadata for priority
		node, exists := sp.gossipState.GetNode(nodeName)
		priority := 100 // Default priority
		if exists {
			priority = node.Priority
		}

		backends = append(backends, &Backend{
			NodeName: nodeName,
			URL:      httpEndpoint,
			Priority: priority,
		})
	}

	return backends
}

// selectBackend selects the best backend (local-first, then by priority)
func (sp *SmartProxy) selectBackend(backends []*Backend, serviceName string) *Backend {
	if len(backends) == 0 {
		return nil
	}

	// Get local node name (from environment or config)
	localNodeName := getLocalNodeName()

	// Prefer local backend
	for _, backend := range backends {
		if backend.NodeName == localNodeName {
			return backend
		}
	}

	// Sort by priority (lower = higher priority)
	bestBackend := backends[0]
	for _, backend := range backends[1:] {
		if backend.Priority < bestBackend.Priority {
			bestBackend = backend
		}
	}

	return bestBackend
}

// buildTargetURL builds the target URL for proxying
func (sp *SmartProxy) buildTargetURL(r *http.Request, backend *Backend) (*url.URL, error) {
	backendURL, err := url.Parse(backend.URL)
	if err != nil {
		return nil, err
	}

	// Preserve path and query
	targetURL := &url.URL{
		Scheme:   backendURL.Scheme,
		Host:     backendURL.Host,
		Path:     r.URL.Path,
		RawQuery: r.URL.RawQuery,
	}

	return targetURL, nil
}

// Helper functions

// Backend represents a backend server
type Backend struct {
	NodeName string
	URL      string
	Priority int
}

func extractServiceName(host string) string {
	// Extract service name from host like "service.domain" or "service.node.domain"
	parts := strings.Split(host, ".")
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}

func removeBackend(backends []*Backend, toRemove *Backend) []*Backend {
	result := make([]*Backend, 0, len(backends))
	for _, backend := range backends {
		if backend.NodeName != toRemove.NodeName {
			result = append(result, backend)
		}
	}
	return result
}

func getScheme(r *http.Request) string {
	if r.TLS != nil {
		return "https"
	}
	if scheme := r.Header.Get("X-Forwarded-Proto"); scheme != "" {
		return scheme
	}
	return "http"
}

func getLocalNodeName() string {
	// TODO: Get from environment or config
	return "localhost"
}
