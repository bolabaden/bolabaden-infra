package smartproxy

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// HealthMetrics holds health and metrics data
type HealthMetrics struct {
	Status          string              `json:"status"`
	Uptime          time.Duration       `json:"uptime"`
	CircuitBreakers map[string]CBStatus `json:"circuit_breakers"`
	Timestamp       time.Time           `json:"timestamp"`
}

// CBStatus represents the status of a circuit breaker
type CBStatus struct {
	State        string `json:"state"`
	FailureCount int    `json:"failure_count"`
	LastFailure  string `json:"last_failure,omitempty"`
	LastSuccess  string `json:"last_success,omitempty"`
}

// HealthHandler handles health check requests
func (sp *SmartProxy) HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	metrics := sp.GetMetrics()
	json.NewEncoder(w).Encode(metrics)
}

// GetMetrics returns current health metrics
func (sp *SmartProxy) GetMetrics() *HealthMetrics {
	sp.mu.RLock()
	defer sp.mu.RUnlock()

	cbStatuses := make(map[string]CBStatus)
	for key, cb := range sp.circuitBreakers {
		state := cb.GetState()
		stateStr := "closed"
		switch state {
		case StateOpen:
			stateStr = "open"
		case StateHalfOpen:
			stateStr = "half_open"
		}

		cbStatus := CBStatus{
			State:        stateStr,
			FailureCount: cb.GetFailureCount(),
		}

		// Get last failure/success times (would need to expose these from CircuitBreaker)
		cbStatuses[key] = cbStatus
	}

	return &HealthMetrics{
		Status:          "healthy",
		CircuitBreakers: cbStatuses,
		Timestamp:       time.Now(),
	}
}

// MetricsHandler handles metrics requests (Prometheus format)
func (sp *SmartProxy) MetricsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)

	sp.mu.RLock()
	defer sp.mu.RUnlock()

	// Simple Prometheus-style metrics
	for key, cb := range sp.circuitBreakers {
		state := cb.GetState()
		stateValue := 0.0
		switch state {
		case StateOpen:
			stateValue = 1.0
		case StateHalfOpen:
			stateValue = 0.5
		}

		w.Write([]byte(fmt.Sprintf("smartproxy_circuit_breaker_state{service=\"%s\"} %f\n", key, stateValue)))
		w.Write([]byte(fmt.Sprintf("smartproxy_circuit_breaker_failures{service=\"%s\"} %d\n", key, cb.GetFailureCount())))
	}
}

// Helper function for metrics
var (
	startTime = time.Now()
	mu        sync.RWMutex
)

func getUptime() time.Duration {
	mu.RLock()
	defer mu.RUnlock()
	return time.Since(startTime)
}
