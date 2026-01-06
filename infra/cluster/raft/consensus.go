package raft

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/hashicorp/raft"
	raftboltdb "github.com/hashicorp/raft-boltdb"
)

// ConsensusManager manages Raft consensus for leader election
type ConsensusManager struct {
	raft      *raft.Raft
	fsm       *RaftFSM
	nodeName  string
	dataDir   string
	bindAddr  string
	bindPort  int
	mu        sync.RWMutex
	callbacks map[LeaseType][]func(bool) // Callbacks for lease changes
}

// Config holds configuration for the consensus manager
type Config struct {
	NodeName  string   // Name of this node
	DataDir   string   // Directory for Raft data (logs, snapshots)
	BindAddr  string   // Address to bind Raft to (Tailscale IP)
	BindPort  int      // Port to bind Raft to
	SeedNodes []string // Initial seed nodes (format: "ip:port")
	LogLevel  string   // Log level for Raft
}

// NewConsensusManager creates a new consensus manager
func NewConsensusManager(config *Config) (*ConsensusManager, error) {
	// Ensure data directory exists
	if err := os.MkdirAll(config.DataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	fsm := NewRaftFSM()

	// Create Raft configuration
	raftConfig := raft.DefaultConfig()
	raftConfig.LocalID = raft.ServerID(config.NodeName)
	// Use default logger (hclog) - can be customized if needed

	// Create transport
	transport, err := raft.NewTCPTransport(
		fmt.Sprintf("%s:%d", config.BindAddr, config.BindPort),
		nil,
		3,
		10*time.Second,
		os.Stderr,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create transport: %w", err)
	}

	// Create log store
	logStorePath := filepath.Join(config.DataDir, "raft", "logs")
	if err := os.MkdirAll(logStorePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create log store directory: %w", err)
	}

	logStore, err := raftboltdb.NewBoltStore(filepath.Join(logStorePath, "raft.db"))
	if err != nil {
		return nil, fmt.Errorf("failed to create log store: %w", err)
	}

	// Create stable store
	stableStorePath := filepath.Join(config.DataDir, "raft", "stable")
	if err := os.MkdirAll(stableStorePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create stable store directory: %w", err)
	}

	stableStore, err := raftboltdb.NewBoltStore(filepath.Join(stableStorePath, "stable.db"))
	if err != nil {
		return nil, fmt.Errorf("failed to create stable store: %w", err)
	}

	// Create snapshot store
	snapshotStore, err := raft.NewFileSnapshotStore(
		filepath.Join(config.DataDir, "raft", "snapshots"),
		3, // Keep 3 snapshots
		os.Stderr,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create snapshot store: %w", err)
	}

	// Create Raft instance
	raftInstance, err := raft.NewRaft(
		raftConfig,
		fsm,
		logStore,
		stableStore,
		snapshotStore,
		transport,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create Raft: %w", err)
	}

	manager := &ConsensusManager{
		raft:      raftInstance,
		fsm:       fsm,
		nodeName:  config.NodeName,
		dataDir:   config.DataDir,
		bindAddr:  config.BindAddr,
		bindPort:  config.BindPort,
		callbacks: make(map[LeaseType][]func(bool)),
	}

	// Bootstrap or join cluster
	if len(config.SeedNodes) == 0 {
		// Bootstrap as single node cluster
		configuration := raft.Configuration{
			Servers: []raft.Server{
				{
					ID:      raft.ServerID(config.NodeName),
					Address: transport.LocalAddr(),
				},
			},
		}
		raftInstance.BootstrapCluster(configuration)
		log.Printf("Bootstrapped Raft cluster as single node")
	} else {
		// Join existing cluster
		if err := manager.JoinCluster(config.SeedNodes); err != nil {
			log.Printf("Warning: failed to join cluster: %v", err)
		}
	}

	// Start monitoring leader changes
	go manager.monitorLeaderChanges()

	return manager, nil
}

// JoinCluster joins an existing Raft cluster
func (cm *ConsensusManager) JoinCluster(seedNodes []string) error {
	log.Printf("Attempting to join Raft cluster via seed nodes: %v", seedNodes)

	// Wait for Raft to be ready
	timeout := 30 * time.Second
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cm.raft.State() != raft.Shutdown {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}

	// Get current configuration
	future := cm.raft.GetConfiguration()
	if err := future.Error(); err != nil {
		return fmt.Errorf("failed to get Raft configuration: %w", err)
	}

	config := future.Configuration()

	// Check if we're already in the cluster
	for _, server := range config.Servers {
		if server.ID == raft.ServerID(cm.nodeName) {
			log.Printf("Node %s is already in the Raft cluster", cm.nodeName)
			return nil
		}
	}

	// Try to add ourselves as a voter
	// We need to contact an existing leader to add us
	// The implementation attempts to add ourselves directly when we become leader,
	// or waits for leader election. In a production environment with a join API endpoint,
	// we would contact that endpoint instead. This implementation handles both scenarios.

	// Check if there's a leader
	if cm.raft.State() == raft.Leader {
		// We're the leader, add ourselves (shouldn't happen in join scenario)
		log.Printf("Warning: Attempting to join but we're already the leader")
		return nil
	}

	// Wait for a leader to be elected
	leaderCh := cm.raft.LeaderCh()
	select {
	case isLeader := <-leaderCh:
		if isLeader {
			// We became leader, add ourselves
			serverID := raft.ServerID(cm.nodeName)
			serverAddr := raft.ServerAddress(fmt.Sprintf("%s:%d", cm.bindAddr, cm.bindPort))

			addFuture := cm.raft.AddVoter(serverID, serverAddr, 0, timeout)
			if err := addFuture.Error(); err != nil {
				return fmt.Errorf("failed to add voter: %w", err)
			}
			log.Printf("Successfully joined Raft cluster as voter")
			return nil
		}
	case <-time.After(10 * time.Second):
		// No leader elected yet, try to bootstrap if we're the first node
		if len(config.Servers) == 0 {
			log.Printf("No existing cluster found, bootstrapping as single node")
			bootstrapConfig := raft.Configuration{
				Servers: []raft.Server{
					{
						ID:      raft.ServerID(cm.nodeName),
						Address: raft.ServerAddress(fmt.Sprintf("%s:%d", cm.bindAddr, cm.bindPort)),
					},
				},
			}
			future := cm.raft.BootstrapCluster(bootstrapConfig)
			if err := future.Error(); err != nil {
				return fmt.Errorf("failed to bootstrap cluster: %w", err)
			}
			log.Printf("Bootstrapped Raft cluster")
			return nil
		}
		return fmt.Errorf("timeout waiting for leader to join cluster")
	}

	return nil
}

// AcquireLease attempts to acquire a lease
func (cm *ConsensusManager) AcquireLease(leaseType LeaseType, leaseID string, term uint64) error {
	if cm.raft.State() != raft.Leader {
		return fmt.Errorf("not the leader, cannot acquire lease")
	}

	cmd := LeaseCommand{
		Action:    "acquire",
		LeaseType: leaseType,
		NodeName:  cm.nodeName,
		LeaseID:   leaseID,
		Term:      term,
	}

	data, err := json.Marshal(cmd)
	if err != nil {
		return fmt.Errorf("failed to marshal command: %w", err)
	}

	future := cm.raft.Apply(data, 5*time.Second)
	if err := future.Error(); err != nil {
		return fmt.Errorf("failed to apply command: %w", err)
	}

	if err, ok := future.Response().(error); ok && err != nil {
		return err
	}

	return nil
}

// ReleaseLease releases a lease
func (cm *ConsensusManager) ReleaseLease(leaseType LeaseType, leaseID string, term uint64) error {
	if cm.raft.State() != raft.Leader {
		return fmt.Errorf("not the leader, cannot release lease")
	}

	cmd := LeaseCommand{
		Action:    "release",
		LeaseType: leaseType,
		NodeName:  cm.nodeName,
		LeaseID:   leaseID,
		Term:      term,
	}

	data, err := json.Marshal(cmd)
	if err != nil {
		return fmt.Errorf("failed to marshal command: %w", err)
	}

	future := cm.raft.Apply(data, 5*time.Second)
	if err := future.Error(); err != nil {
		return fmt.Errorf("failed to apply command: %w", err)
	}

	if err, ok := future.Response().(error); ok && err != nil {
		return err
	}

	return nil
}

// IsLeader returns whether this node is the Raft leader
func (cm *ConsensusManager) IsLeader() bool {
	return cm.raft.State() == raft.Leader
}

// GetLease returns the current lease for a given type
func (cm *ConsensusManager) GetLease(leaseType LeaseType) *Lease {
	return cm.fsm.GetLease(leaseType)
}

// HasLease returns whether this node holds a specific lease
func (cm *ConsensusManager) HasLease(leaseType LeaseType) bool {
	lease := cm.fsm.GetLease(leaseType)
	return lease != nil && lease.NodeName == cm.nodeName
}

// RegisterLeaseCallback registers a callback for lease changes
func (cm *ConsensusManager) RegisterLeaseCallback(leaseType LeaseType, callback func(bool)) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.callbacks[leaseType] = append(cm.callbacks[leaseType], callback)
}

// monitorLeaderChanges monitors Raft state changes and triggers callbacks
func (cm *ConsensusManager) monitorLeaderChanges() {
	wasLeader := false
	hadLeases := make(map[LeaseType]bool)

	for {
		time.Sleep(1 * time.Second)

		isLeader := cm.IsLeader()
		if isLeader != wasLeader {
			log.Printf("Raft leadership changed: isLeader=%v", isLeader)
			wasLeader = isLeader
		}

		// Check lease ownership changes
		for leaseType := range cm.callbacks {
			hasLease := cm.HasLease(leaseType)
			if hadLeases[leaseType] != hasLease {
				log.Printf("Lease %s ownership changed: hasLease=%v", leaseType, hasLease)
				hadLeases[leaseType] = hasLease

				// Trigger callbacks
				cm.mu.RLock()
				callbacks := cm.callbacks[leaseType]
				cm.mu.RUnlock()

				for _, callback := range callbacks {
					go callback(hasLease)
				}
			}
		}
	}
}

// Shutdown shuts down the consensus manager
func (cm *ConsensusManager) Shutdown() error {
	future := cm.raft.Shutdown()
	if err := future.Error(); err != nil {
		return fmt.Errorf("failed to shutdown Raft: %w", err)
	}
	return nil
}

// GetState returns the current Raft state
func (cm *ConsensusManager) GetState() raft.RaftState {
	return cm.raft.State()
}

// GetLeader returns the current leader address
func (cm *ConsensusManager) GetLeader() raft.ServerAddress {
	return cm.raft.Leader()
}
