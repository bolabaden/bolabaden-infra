package dns

import (
	"log"
	"sync"
	"time"
)

// Controller manages DNS updates based on Raft lease ownership
type Controller struct {
	reconciler *DNSReconciler
	hasLease   bool
	mu         sync.RWMutex
	stopCh     chan struct{}
	updateCh   chan updateRequest
}

// updateRequest represents a DNS update request
type updateRequest struct {
	lbLeaderIP string
	nodeIPs    map[string]string
}

// NewController creates a new DNS controller
func NewController(reconciler *DNSReconciler) *Controller {
	return &Controller{
		reconciler: reconciler,
		hasLease:   false,
		stopCh:     make(chan struct{}),
		updateCh:   make(chan updateRequest, 100),
	}
}

// SetLeaseOwnership updates whether this node holds the DNS writer lease
func (dc *Controller) SetLeaseOwnership(hasLease bool) {
	dc.mu.Lock()
	wasLeader := dc.hasLease
	dc.hasLease = hasLease
	dc.mu.Unlock()

	if hasLease && !wasLeader {
		log.Printf("DNS controller: acquired DNS writer lease, starting reconciliation")
		go dc.reconciliationLoop()
	} else if !hasLease && wasLeader {
		log.Printf("DNS controller: lost DNS writer lease, stopping reconciliation")
	}
}

// UpdateLBLeader requests an update to the LB leader DNS records
func (dc *Controller) UpdateLBLeader(lbLeaderIP string) {
	dc.mu.RLock()
	hasLease := dc.hasLease
	dc.mu.RUnlock()

	if !hasLease {
		log.Printf("DNS controller: not holding DNS writer lease, ignoring LB leader update")
		return
	}

	select {
	case dc.updateCh <- updateRequest{lbLeaderIP: lbLeaderIP}:
	default:
		log.Printf("DNS controller: update channel full, dropping LB leader update")
	}
}

// UpdateNodeIPs requests an update to node-specific DNS records
func (dc *Controller) UpdateNodeIPs(nodeIPs map[string]string) {
	dc.mu.RLock()
	hasLease := dc.hasLease
	dc.mu.RUnlock()

	if !hasLease {
		log.Printf("DNS controller: not holding DNS writer lease, ignoring node IPs update")
		return
	}

	select {
	case dc.updateCh <- updateRequest{nodeIPs: nodeIPs}:
	default:
		log.Printf("DNS controller: update channel full, dropping node IPs update")
	}
}

// reconciliationLoop processes DNS update requests
func (dc *Controller) reconciliationLoop() {
	ticker := time.NewTicker(30 * time.Second) // Periodic reconciliation
	defer ticker.Stop()

	var lastLBLeaderIP string
	var lastNodeIPs map[string]string

	for {
		select {
		case req := <-dc.updateCh:
			if req.lbLeaderIP != "" {
				lastLBLeaderIP = req.lbLeaderIP
			}
			if req.nodeIPs != nil {
				lastNodeIPs = req.nodeIPs
			}

			// Process updates immediately
			dc.processUpdates(lastLBLeaderIP, lastNodeIPs)

		case <-ticker.C:
			// Periodic reconciliation to handle drift
			dc.mu.RLock()
			hasLease := dc.hasLease
			dc.mu.RUnlock()

			if !hasLease {
				return // Stop if we lost the lease
			}

			dc.processUpdates(lastLBLeaderIP, lastNodeIPs)

		case <-dc.stopCh:
			return
		}
	}
}

// processUpdates processes DNS updates
func (dc *Controller) processUpdates(lbLeaderIP string, nodeIPs map[string]string) {
	dc.mu.RLock()
	hasLease := dc.hasLease
	dc.mu.RUnlock()

	if !hasLease {
		return
	}

	// Update LB leader records
	if lbLeaderIP != "" {
		if err := dc.reconciler.UpdateLBLeaderRecord(lbLeaderIP); err != nil {
			log.Printf("DNS controller: failed to update LB leader records: %v", err)
		}
	}

	// Update node-specific records
	if nodeIPs != nil && len(nodeIPs) > 0 {
		if err := dc.reconciler.ReconcileAllNodes(nodeIPs); err != nil {
			log.Printf("DNS controller: failed to update node records: %v", err)
		}
	}
}

// Shutdown shuts down the DNS controller
func (dc *Controller) Shutdown() {
	close(dc.stopCh)
}
