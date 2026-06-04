package raft

import (
	"encoding/json"
	"fmt"
	"io"
	"sync"

	"github.com/hashicorp/raft"
)

// LeaseType represents the type of lease
type LeaseType string

const (
	LeaseTypeLBLeader  LeaseType = "lb_leader"
	LeaseTypeDNSWriter LeaseType = "dns_writer"
	LeaseTypeService   LeaseType = "service"
)

// Lease represents a leader lease
type Lease struct {
	Type       LeaseType `json:"type"`
	Target     string    `json:"target,omitempty"` // Service name or other specific target
	NodeName   string    `json:"node_name"`
	Term       uint64    `json:"term"`
	LeaseID    string    `json:"lease_id"`
	AcquiredAt int64     `json:"acquired_at"` // Unix timestamp
}

// LeaseCommand represents a command to acquire or release a lease
type LeaseCommand struct {
	Action    string    `json:"action"` // "acquire" or "release"
	LeaseType LeaseType `json:"lease_type"`
	Target    string    `json:"target,omitempty"`
	NodeName  string    `json:"node_name"`
	LeaseID   string    `json:"lease_id"`
	Term      uint64    `json:"term"`
}

// RaftFSM implements the Raft FSM for managing leader leases
type RaftFSM struct {
	mu     sync.RWMutex
	leases map[string]*Lease // Combined key: type + ":" + target
}

// NewRaftFSM creates a new Raft FSM
func NewRaftFSM() *RaftFSM {
	return &RaftFSM{
		leases: make(map[string]*Lease),
	}
}

// getLeaseKey returns a unique key for the lease map
func getLeaseKey(leaseType LeaseType, target string) string {
	if target == "" {
		return string(leaseType)
	}
	return fmt.Sprintf("%s:%s", leaseType, target)
}

// Apply applies a log entry to the FSM
func (f *RaftFSM) Apply(log *raft.Log) interface{} {
	var cmd LeaseCommand
	if err := json.Unmarshal(log.Data, &cmd); err != nil {
		return fmt.Errorf("failed to unmarshal command: %w", err)
	}

	f.mu.Lock()
	defer f.mu.Unlock()

	switch cmd.Action {
	case "acquire":
		return f.acquireLease(&cmd, log.Index)
	case "release":
		return f.releaseLease(&cmd)
	default:
		return fmt.Errorf("unknown action: %s", cmd.Action)
	}
}

// acquireLease acquires a lease if it's not already held or if the term is higher
func (f *RaftFSM) acquireLease(cmd *LeaseCommand, logIndex uint64) error {
	key := getLeaseKey(cmd.LeaseType, cmd.Target)
	currentLease, exists := f.leases[key]

	// If lease doesn't exist, or if the new term is higher, acquire it
	if !exists || cmd.Term > currentLease.Term {
		f.leases[key] = &Lease{
			Type:       cmd.LeaseType,
			Target:     cmd.Target,
			NodeName:   cmd.NodeName,
			Term:       cmd.Term,
			LeaseID:    cmd.LeaseID,
			AcquiredAt: int64(logIndex), // Use log index as timestamp proxy
		}
		return nil
	}

	// If same term but different node, reject (split-brain prevention)
	if cmd.Term == currentLease.Term && cmd.NodeName != currentLease.NodeName {
		return fmt.Errorf("lease %s already held by %s in term %d", key, currentLease.NodeName, cmd.Term)
	}

	// Same node, same term - renew lease
	f.leases[key] = &Lease{
		Type:       cmd.LeaseType,
		Target:     cmd.Target,
		NodeName:   cmd.NodeName,
		Term:       cmd.Term,
		LeaseID:    cmd.LeaseID,
		AcquiredAt: int64(logIndex),
	}

	return nil
}

// releaseLease releases a lease if it's held by the requesting node
func (f *RaftFSM) releaseLease(cmd *LeaseCommand) error {
	key := getLeaseKey(cmd.LeaseType, cmd.Target)
	currentLease, exists := f.leases[key]
	if !exists {
		return nil // Already released
	}

	// Only allow release if it's the same node and term
	if currentLease.NodeName != cmd.NodeName || currentLease.Term != cmd.Term {
		return fmt.Errorf("cannot release lease %s: held by %s (term %d), requested by %s (term %d)",
			key, currentLease.NodeName, currentLease.Term, cmd.NodeName, cmd.Term)
	}

	delete(f.leases, key)
	return nil
}

// Snapshot returns a snapshot of the FSM state
func (f *RaftFSM) Snapshot() (raft.FSMSnapshot, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()

	// Create a copy of leases
	leasesCopy := make(map[string]*Lease)
	for k, v := range f.leases {
		leaseCopy := *v
		leasesCopy[k] = &leaseCopy
	}

	return &fsmSnapshot{leases: leasesCopy}, nil
}

// Restore restores the FSM from a snapshot
func (f *RaftFSM) Restore(reader io.ReadCloser) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	var snapshotData struct {
		Leases map[string]*Lease `json:"leases"`
	}

	if err := json.NewDecoder(reader).Decode(&snapshotData); err != nil {
		return fmt.Errorf("failed to decode snapshot: %w", err)
	}

	f.leases = snapshotData.Leases
	return nil
}

// GetLease returns the current lease for a given type and optional target
func (f *RaftFSM) GetLease(leaseType LeaseType, target string) *Lease {
	f.mu.RLock()
	defer f.mu.RUnlock()

	key := getLeaseKey(leaseType, target)
	lease, exists := f.leases[key]
	if !exists {
		return nil
	}

	// Return a copy to prevent external modification
	leaseCopy := *lease
	return &leaseCopy
}

// GetAllLeases returns all current leases
func (f *RaftFSM) GetAllLeases() map[string]*Lease {
	f.mu.RLock()
	defer f.mu.RUnlock()

	leasesCopy := make(map[string]*Lease)
	for k, v := range f.leases {
		leaseCopy := *v
		leasesCopy[k] = &leaseCopy
	}

	return leasesCopy
}

// fsmSnapshot implements raft.FSMSnapshot
type fsmSnapshot struct {
	leases map[string]*Lease
}

// Persist persists the snapshot to the given sink
func (s *fsmSnapshot) Persist(sink raft.SnapshotSink) error {
	data, err := json.Marshal(map[string]interface{}{
		"leases": s.leases,
	})
	if err != nil {
		sink.Cancel()
		return fmt.Errorf("failed to marshal snapshot: %w", err)
	}

	if _, err := sink.Write(data); err != nil {
		sink.Cancel()
		return fmt.Errorf("failed to write snapshot: %w", err)
	}

	return sink.Close()
}

// Release releases resources associated with the snapshot
func (s *fsmSnapshot) Release() {
	// No resources to release
}
