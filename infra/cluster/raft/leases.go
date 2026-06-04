package raft

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
)

// LeaseManager provides high-level lease management with automatic renewal
type LeaseManager struct {
	consensus    *ConsensusManager
	nodeName     string
	currentTerm  uint64
	leaseIDs     map[string]string // Key: "type:target", Value: leaseID
	renewalTimer *time.Ticker
	mu           sync.RWMutex
	stopCh       chan struct{}
}

// NewLeaseManager creates a new lease manager
func NewLeaseManager(consensus *ConsensusManager, nodeName string) *LeaseManager {
	lm := &LeaseManager{
		consensus:   consensus,
		nodeName:    nodeName,
		currentTerm: 1,
		leaseIDs:    make(map[string]string),
		stopCh:      make(chan struct{}),
	}

	// Start renewal timer
	lm.renewalTimer = time.NewTicker(5 * time.Second)
	go lm.renewalLoop()

	return lm
}

// getLeaseKey returns a unique key for the leaseIDs map
func (lm *LeaseManager) getLeaseKey(leaseType LeaseType, target string) string {
	if target == "" {
		return string(leaseType)
	}
	return fmt.Sprintf("%s:%s", leaseType, target)
}

// AcquireLBLeaderLease attempts to acquire the LB leader lease
func (lm *LeaseManager) AcquireLBLeaderLease() error {
	return lm.acquireLease(LeaseTypeLBLeader, "")
}

// AcquireDNSWriterLease attempts to acquire the DNS writer lease
func (lm *LeaseManager) AcquireDNSWriterLease() error {
	return lm.acquireLease(LeaseTypeDNSWriter, "")
}

// AcquireServiceLease attempts to acquire a lease for a specific service
func (lm *LeaseManager) AcquireServiceLease(serviceName string) error {
	return lm.acquireLease(LeaseTypeService, serviceName)
}

// acquireLease attempts to acquire a lease
func (lm *LeaseManager) acquireLease(leaseType LeaseType, target string) error {
	lm.mu.Lock()
	defer lm.mu.Unlock()

	key := lm.getLeaseKey(leaseType, target)

	// Check if we already have this lease
	if leaseID, exists := lm.leaseIDs[key]; exists {
		currentLease := lm.consensus.GetLease(leaseType, target)
		if currentLease != nil && currentLease.NodeName == lm.nodeName && currentLease.LeaseID == leaseID {
			// Already have the lease, renew it
			return lm.renewLeaseLocked(leaseType, target, leaseID)
		}
	}

	// Only try to acquire if we're the leader
	if !lm.consensus.IsLeader() {
		return fmt.Errorf("not the Raft leader, cannot acquire lease")
	}

	// Generate new lease ID
	leaseID := uuid.New().String()
	lm.leaseIDs[key] = leaseID

	// Increment term for new lease acquisition
	lm.currentTerm++

	// Try to acquire the lease
	if err := lm.consensus.AcquireLease(leaseType, target, leaseID, lm.currentTerm); err != nil {
		delete(lm.leaseIDs, key)
		return fmt.Errorf("failed to acquire lease %s: %w", key, err)
	}

	log.Printf("Acquired lease %s (leaseID: %s, term: %d)", key, leaseID, lm.currentTerm)
	return nil
}

// renewLeaseLocked renews an existing lease (must be called with lock held)
func (lm *LeaseManager) renewLeaseLocked(leaseType LeaseType, target string, leaseID string) error {
	if !lm.consensus.IsLeader() {
		return fmt.Errorf("not the Raft leader, cannot renew lease")
	}

	// Renew with same term (lease renewal, not new acquisition)
	if err := lm.consensus.AcquireLease(leaseType, target, leaseID, lm.currentTerm); err != nil {
		return fmt.Errorf("failed to renew lease %s:%s: %w", leaseType, target, err)
	}

	return nil
}

// ReleaseLease releases a lease
func (lm *LeaseManager) ReleaseLease(leaseType LeaseType, target string) error {
	lm.mu.Lock()
	defer lm.mu.Unlock()

	key := lm.getLeaseKey(leaseType, target)
	leaseID, exists := lm.leaseIDs[key]
	if !exists {
		return nil // Already released
	}

	if !lm.consensus.IsLeader() {
		// If we're not leader, just remove from local tracking
		delete(lm.leaseIDs, key)
		return nil
	}

	if err := lm.consensus.ReleaseLease(leaseType, target, leaseID, lm.currentTerm); err != nil {
		return fmt.Errorf("failed to release lease %s: %w", key, err)
	}

	delete(lm.leaseIDs, key)
	log.Printf("Released lease %s", key)
	return nil
}

// HasLease returns whether this node holds a specific lease
func (lm *LeaseManager) HasLease(leaseType LeaseType, target string) bool {
	lm.mu.RLock()
	defer lm.mu.RUnlock()

	key := lm.getLeaseKey(leaseType, target)
	leaseID, exists := lm.leaseIDs[key]
	if !exists {
		return false
	}

	lease := lm.consensus.GetLease(leaseType, target)
	return lease != nil && lease.NodeName == lm.nodeName && lease.LeaseID == leaseID
}

// GetLeaseFencingToken returns a fencing token for a lease (term + leaseID)
func (lm *LeaseManager) GetLeaseFencingToken(leaseType LeaseType, target string) (uint64, string, error) {
	lm.mu.RLock()
	defer lm.mu.RUnlock()

	key := lm.getLeaseKey(leaseType, target)
	leaseID, exists := lm.leaseIDs[key]
	if !exists {
		return 0, "", fmt.Errorf("lease %s not held by this node", key)
	}

	lease := lm.consensus.GetLease(leaseType, target)
	if lease == nil || lease.NodeName != lm.nodeName || lease.LeaseID != leaseID {
		return 0, "", fmt.Errorf("lease %s not valid", key)
	}

	return lease.Term, lease.LeaseID, nil
}

// renewalLoop periodically renews active leases
func (lm *LeaseManager) renewalLoop() {
	for {
		select {
		case <-lm.renewalTimer.C:
			lm.mu.RLock()
			keysToRenew := make([]string, 0, len(lm.leaseIDs))
			for key := range lm.leaseIDs {
				keysToRenew = append(keysToRenew, key)
			}
			lm.mu.RUnlock()

			for _, key := range keysToRenew {
				lm.mu.RLock()
				leaseID, exists := lm.leaseIDs[key]
				lm.mu.RUnlock()

				if !exists {
					continue
				}

				// Key is "type:target" or just "type"
				// Parse type and target from key
				// Since LeaseType constant values don't contain ":", we can split
				var leaseType LeaseType
				var target string
				
				// Find first ":"
				idx := -1
				for i, r := range key {
					if r == ':' {
						idx = i
						break
					}
				}

				if idx != -1 {
					leaseType = LeaseType(key[:idx])
					target = key[idx+1:]
				} else {
					leaseType = LeaseType(key)
					target = ""
				}

				// Only renew if we're the leader and still hold the lease
				if lm.consensus.IsLeader() && lm.HasLease(leaseType, target) {
					lm.mu.Lock()
					if err := lm.renewLeaseLocked(leaseType, target, leaseID); err != nil {
						log.Printf("Failed to renew lease %s:%s: %v", leaseType, target, err)
						// If renewal fails, remove from tracking
						delete(lm.leaseIDs, key)
					}
					lm.mu.Unlock()
				}
			}

		case <-lm.stopCh:
			return
		}
	}
}

// Shutdown shuts down the lease manager
func (lm *LeaseManager) Shutdown() {
	lm.renewalTimer.Stop()
	close(lm.stopCh)

	// Release all leases
	lm.mu.Lock()
	defer lm.mu.Unlock()

	for key, leaseID := range lm.leaseIDs {
		// Parse type and target from key
		var leaseType LeaseType
		var target string
		
		idx := -1
		for i, r := range key {
			if r == ':' {
				idx = i
				break
			}
		}

		if idx != -1 {
			leaseType = LeaseType(key[:idx])
			target = key[idx+1:]
		} else {
			leaseType = LeaseType(key)
			target = ""
		}

		if err := lm.consensus.ReleaseLease(leaseType, target, leaseID, lm.currentTerm); err != nil {
			log.Printf("Failed to release lease %s:%s on shutdown: %v", leaseType, target, err)
		}
	}
}
