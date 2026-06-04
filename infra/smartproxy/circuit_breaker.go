package smartproxy

import (
	"log"
	"sync"
	"time"
)

// CircuitBreakerState represents the state of a circuit breaker
type CircuitBreakerState int

const (
	StateClosed CircuitBreakerState = iota
	StateOpen
	StateHalfOpen
)

// CircuitBreaker implements a circuit breaker pattern
type CircuitBreaker struct {
	serviceName string
	nodeName    string
	state       CircuitBreakerState
	mu          sync.RWMutex

	// Configuration
	failureThreshold int           // Number of failures before opening
	successThreshold int           // Number of successes in half-open to close
	timeout          time.Duration // Time to wait before attempting half-open

	// Counters
	failureCount int
	successCount int
	lastFailure  time.Time
	lastSuccess  time.Time
}

// NewCircuitBreaker creates a new circuit breaker
func NewCircuitBreaker(serviceName, nodeName string) *CircuitBreaker {
	return &CircuitBreaker{
		serviceName:      serviceName,
		nodeName:         nodeName,
		state:            StateClosed,
		failureThreshold: 5,                // Open after 5 failures
		successThreshold: 2,                // Close after 2 successes in half-open
		timeout:          30 * time.Second, // Wait 30s before half-open
	}
}

// Allow checks if the circuit breaker allows a request
func (cb *CircuitBreaker) Allow() bool {
	cb.mu.RLock()
	defer cb.mu.RUnlock()

	switch cb.state {
	case StateClosed:
		return true
	case StateOpen:
		// Check if timeout has passed
		if time.Since(cb.lastFailure) >= cb.timeout {
			// Transition to half-open (will be done in RecordSuccess/Failure)
			return true
		}
		return false
	case StateHalfOpen:
		return true
	default:
		return false
	}
}

// RecordSuccess records a successful request
func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.lastSuccess = time.Now()

	switch cb.state {
	case StateClosed:
		// Reset failure count on success
		cb.failureCount = 0
	case StateHalfOpen:
		cb.successCount++
		if cb.successCount >= cb.successThreshold {
			// Transition to closed
			cb.state = StateClosed
			cb.failureCount = 0
			cb.successCount = 0
			log.Printf("Circuit breaker closed for %s@%s", cb.serviceName, cb.nodeName)
		}
	}
}

// RecordFailure records a failed request
func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.lastFailure = time.Now()

	switch cb.state {
	case StateClosed:
		cb.failureCount++
		if cb.failureCount >= cb.failureThreshold {
			// Transition to open
			cb.state = StateOpen
			log.Printf("Circuit breaker opened for %s@%s (failures: %d)", cb.serviceName, cb.nodeName, cb.failureCount)
		}
	case StateHalfOpen:
		// Any failure in half-open immediately opens
		cb.state = StateOpen
		cb.failureCount = cb.failureThreshold
		cb.successCount = 0
		log.Printf("Circuit breaker reopened for %s@%s (failure in half-open)", cb.serviceName, cb.nodeName)
	}
}

// GetState returns the current state of the circuit breaker
func (cb *CircuitBreaker) GetState() CircuitBreakerState {
	cb.mu.RLock()
	defer cb.mu.RUnlock()

	// Check if we should transition from open to half-open
	if cb.state == StateOpen && time.Since(cb.lastFailure) >= cb.timeout {
		cb.mu.RUnlock()
		cb.mu.Lock()
		if cb.state == StateOpen && time.Since(cb.lastFailure) >= cb.timeout {
			cb.state = StateHalfOpen
			cb.successCount = 0
			log.Printf("Circuit breaker half-open for %s@%s", cb.serviceName, cb.nodeName)
		}
		cb.mu.Unlock()
		cb.mu.RLock()
	}

	return cb.state
}

// GetFailureCount returns the current failure count
func (cb *CircuitBreaker) GetFailureCount() int {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.failureCount
}
