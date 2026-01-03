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
	leaseIDs     map[LeaseType]string
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
		leaseIDs:    make(map[LeaseType]string),
		stopCh:      make(chan struct{}),
	}

	// Start renewal timer
	lm.renewalTimer = time.NewTicker(5 * time.Second)
	go lm.renewalLoop()

	return lm
}

// AcquireLBLeaderLease attempts to acquire the LB leader lease
func (lm *LeaseManager) AcquireLBLeaderLease() error {
	return lm.acquireLease(LeaseTypeLBLeader)
}

// AcquireDNSWriterLease attempts to acquire the DNS writer lease
func (lm *LeaseManager) AcquireDNSWriterLease() error {
	return lm.acquireLease(LeaseTypeDNSWriter)
}

// acquireLease attempts to acquire a lease
func (lm *LeaseManager) acquireLease(leaseType LeaseType) error {
	lm.mu.Lock()
	defer lm.mu.Unlock()

	// Check if we already have this lease
	if leaseID, exists := lm.leaseIDs[leaseType]; exists {
		currentLease := lm.consensus.GetLease(leaseType)
		if currentLease != nil && currentLease.NodeName == lm.nodeName && currentLease.LeaseID == leaseID {
			// Already have the lease, renew it
			return lm.renewLeaseLocked(leaseType, leaseID)
		}
	}

	// Only try to acquire if we're the leader
	if !lm.consensus.IsLeader() {
		return fmt.Errorf("not the Raft leader, cannot acquire lease")
	}

	// Generate new lease ID
	leaseID := uuid.New().String()
	lm.leaseIDs[leaseType] = leaseID

	// Increment term for new lease acquisition
	lm.currentTerm++

	// Try to acquire the lease
	if err := lm.consensus.AcquireLease(leaseType, leaseID, lm.currentTerm); err != nil {
		delete(lm.leaseIDs, leaseType)
		return fmt.Errorf("failed to acquire lease %s: %w", leaseType, err)
	}

	log.Printf("Acquired lease %s (leaseID: %s, term: %d)", leaseType, leaseID, lm.currentTerm)
	return nil
}

// renewLeaseLocked renews an existing lease (must be called with lock held)
func (lm *LeaseManager) renewLeaseLocked(leaseType LeaseType, leaseID string) error {
	if !lm.consensus.IsLeader() {
		return fmt.Errorf("not the Raft leader, cannot renew lease")
	}

	// Renew with same term (lease renewal, not new acquisition)
	if err := lm.consensus.AcquireLease(leaseType, leaseID, lm.currentTerm); err != nil {
		return fmt.Errorf("failed to renew lease %s: %w", leaseType, err)
	}

	return nil
}

// ReleaseLease releases a lease
func (lm *LeaseManager) ReleaseLease(leaseType LeaseType) error {
	lm.mu.Lock()
	defer lm.mu.Unlock()

	leaseID, exists := lm.leaseIDs[leaseType]
	if !exists {
		return nil // Already released
	}

	if !lm.consensus.IsLeader() {
		// If we're not leader, just remove from local tracking
		delete(lm.leaseIDs, leaseType)
		return nil
	}

	if err := lm.consensus.ReleaseLease(leaseType, leaseID, lm.currentTerm); err != nil {
		return fmt.Errorf("failed to release lease %s: %w", leaseType, err)
	}

	delete(lm.leaseIDs, leaseType)
	log.Printf("Released lease %s", leaseType)
	return nil
}

// HasLease returns whether this node holds a specific lease
func (lm *LeaseManager) HasLease(leaseType LeaseType) bool {
	lm.mu.RLock()
	defer lm.mu.RUnlock()

	leaseID, exists := lm.leaseIDs[leaseType]
	if !exists {
		return false
	}

	lease := lm.consensus.GetLease(leaseType)
	return lease != nil && lease.NodeName == lm.nodeName && lease.LeaseID == leaseID
}

// GetLeaseFencingToken returns a fencing token for a lease (term + leaseID)
func (lm *LeaseManager) GetLeaseFencingToken(leaseType LeaseType) (uint64, string, error) {
	lm.mu.RLock()
	defer lm.mu.RUnlock()

	leaseID, exists := lm.leaseIDs[leaseType]
	if !exists {
		return 0, "", fmt.Errorf("lease %s not held by this node", leaseType)
	}

	lease := lm.consensus.GetLease(leaseType)
	if lease == nil || lease.NodeName != lm.nodeName || lease.LeaseID != leaseID {
		return 0, "", fmt.Errorf("lease %s not valid", leaseType)
	}

	return lease.Term, lease.LeaseID, nil
}

// renewalLoop periodically renews active leases
func (lm *LeaseManager) renewalLoop() {
	for {
		select {
		case <-lm.renewalTimer.C:
			lm.mu.RLock()
			leasesToRenew := make([]LeaseType, 0, len(lm.leaseIDs))
			for leaseType := range lm.leaseIDs {
				leasesToRenew = append(leasesToRenew, leaseType)
			}
			lm.mu.RUnlock()

			for _, leaseType := range leasesToRenew {
				lm.mu.RLock()
				leaseID, exists := lm.leaseIDs[leaseType]
				lm.mu.RUnlock()

				if !exists {
					continue
				}

				// Only renew if we're the leader and still hold the lease
				if lm.consensus.IsLeader() && lm.HasLease(leaseType) {
					lm.mu.Lock()
					if err := lm.renewLeaseLocked(leaseType, leaseID); err != nil {
						log.Printf("Failed to renew lease %s: %v", leaseType, err)
						// If renewal fails, remove from tracking
						delete(lm.leaseIDs, leaseType)
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

	for leaseType := range lm.leaseIDs {
		if err := lm.consensus.ReleaseLease(leaseType, lm.leaseIDs[leaseType], lm.currentTerm); err != nil {
			log.Printf("Failed to release lease %s on shutdown: %v", leaseType, err)
		}
	}
}
