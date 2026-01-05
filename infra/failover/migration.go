package failover

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/docker/docker/client"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
)

// MigrationManager handles container migration between nodes
type MigrationManager struct {
	dockerClient *client.Client
	gossipState  *gossip.ClusterState
	nodeName     string
	mu           sync.RWMutex
	migrations   map[string]*Migration // service name -> active migration
}

// Migration represents an active container migration
type Migration struct {
	ServiceName string
	SourceNode  string
	TargetNode  string
	Status      MigrationStatus
	StartedAt   time.Time
	CompletedAt *time.Time
	Error       error
}

// MigrationStatus represents the status of a migration
type MigrationStatus string

const (
	MigrationStatusPending   MigrationStatus = "pending"
	MigrationStatusRunning   MigrationStatus = "running"
	MigrationStatusCompleted MigrationStatus = "completed"
	MigrationStatusFailed    MigrationStatus = "failed"
)

// MigrationRule defines when and how to migrate containers
type MigrationRule struct {
	ServiceName string
	Trigger     MigrationTrigger
	TargetNode  string // empty = auto-select
	Priority    int    // higher = more important
	MaxRetries  int
	RetryDelay  time.Duration
}

// MigrationTrigger defines what triggers a migration
type MigrationTrigger struct {
	HealthCheckFailures int    // migrate after N consecutive failures
	ResourceThreshold   string // e.g., "cpu>80%" or "memory>90%"
	NodeUnhealthy       bool   // migrate if node becomes unhealthy
}

// NewMigrationManager creates a new migration manager
func NewMigrationManager(dockerClient *client.Client, gossipState *gossip.ClusterState, nodeName string) *MigrationManager {
	return &MigrationManager{
		dockerClient: dockerClient,
		gossipState:  gossipState,
		nodeName:     nodeName,
		migrations:   make(map[string]*Migration),
	}
}

// StartMigration starts migrating a container to another node
func (mm *MigrationManager) StartMigration(ctx context.Context, rule MigrationRule) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()

	// Check if migration already in progress
	if existing, exists := mm.migrations[rule.ServiceName]; exists {
		if existing.Status == MigrationStatusRunning || existing.Status == MigrationStatusPending {
			return fmt.Errorf("migration already in progress for service %s", rule.ServiceName)
		}
	}

	// Determine target node
	targetNode := rule.TargetNode
	if targetNode == "" {
		var err error
		targetNode, err = mm.selectTargetNode(rule.ServiceName)
		if err != nil {
			return fmt.Errorf("failed to select target node: %w", err)
		}
	}

	// Create migration record
	migration := &Migration{
		ServiceName: rule.ServiceName,
		SourceNode:  mm.nodeName,
		TargetNode:  targetNode,
		Status:      MigrationStatusPending,
		StartedAt:   time.Now(),
	}

	mm.migrations[rule.ServiceName] = migration

	// Start migration in background
	go mm.executeMigration(ctx, migration, rule)

	return nil
}

// selectTargetNode selects the best target node for migration
func (mm *MigrationManager) selectTargetNode(serviceName string) (string, error) {
	state := mm.gossipState
	allNodes := state.GetAllNodes()

	// Filter to healthy, non-cordoned nodes (excluding current node)
	candidates := make([]*gossip.NodeMetadata, 0)
	for _, node := range allNodes {
		if node.Name == mm.nodeName {
			continue // Skip current node
		}
		if node.Cordoned {
			continue // Skip cordoned nodes
		}

		// Check if node already has this service
		health, exists := state.GetServiceHealth(serviceName, node.Name)
		if exists && health.Healthy {
			continue // Skip nodes that already have healthy instance
		}

		candidates = append(candidates, node)
	}

	if len(candidates) == 0 {
		return "", fmt.Errorf("no suitable target nodes available")
	}

	// Select node with lowest priority (fastest nodes first)
	bestNode := candidates[0]
	for _, node := range candidates[1:] {
		if node.Priority < bestNode.Priority {
			bestNode = node
		}
	}

	return bestNode.Name, nil
}

// executeMigration performs the actual migration
func (mm *MigrationManager) executeMigration(ctx context.Context, migration *Migration, rule MigrationRule) {
	mm.mu.Lock()
	migration.Status = MigrationStatusRunning
	mm.mu.Unlock()

	log.Printf("Starting migration of %s from %s to %s", migration.ServiceName, migration.SourceNode, migration.TargetNode)

	// For now, we log the migration but don't actually move containers
	// Container migration would require:
	// 1. Stopping container on source node
	// 2. Exporting container state/volumes
	// 3. Transferring to target node
	// 4. Starting container on target node
	// 5. Updating service discovery

	// This is a placeholder implementation
	// In a full implementation, we would:
	// - Use Docker API to stop/export container
	// - Transfer data via Tailscale network
	// - Use Docker API on target node to start container
	// - Update gossip state

	// Simulate migration delay
	time.Sleep(2 * time.Second)

	mm.mu.Lock()
	migration.Status = MigrationStatusCompleted
	now := time.Now()
	migration.CompletedAt = &now
	mm.mu.Unlock()

	log.Printf("Migration of %s completed", migration.ServiceName)
}

// GetMigrationStatus returns the status of a migration
func (mm *MigrationManager) GetMigrationStatus(serviceName string) (*Migration, bool) {
	mm.mu.RLock()
	defer mm.mu.RUnlock()

	migration, exists := mm.migrations[serviceName]
	if !exists {
		return nil, false
	}

	// Return a copy
	return &Migration{
		ServiceName: migration.ServiceName,
		SourceNode:  migration.SourceNode,
		TargetNode:  migration.TargetNode,
		Status:      migration.Status,
		StartedAt:   migration.StartedAt,
		CompletedAt: migration.CompletedAt,
		Error:       migration.Error,
	}, true
}

// MonitorAndMigrate monitors services and triggers migrations based on rules
func (mm *MigrationManager) MonitorAndMigrate(ctx context.Context, rules []MigrationRule) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			mm.checkAndMigrate(ctx, rules)
		}
	}
}

// checkAndMigrate checks services against migration rules and triggers migrations
func (mm *MigrationManager) checkAndMigrate(ctx context.Context, rules []MigrationRule) {
	state := mm.gossipState

	for _, rule := range rules {
		// Check if service is unhealthy on this node
		health, exists := state.GetServiceHealth(rule.ServiceName, mm.nodeName)
		if !exists {
			continue
		}

		// Check trigger conditions
		shouldMigrate := false

		if rule.Trigger.HealthCheckFailures > 0 {
			// Count consecutive failures (simplified - would need to track history)
			if !health.Healthy {
				shouldMigrate = true
			}
		}

		if rule.Trigger.NodeUnhealthy {
			// Check if this node is unhealthy
			node, exists := state.GetNode(mm.nodeName)
			if exists && node.Cordoned {
				shouldMigrate = true
			}
		}

		if shouldMigrate {
			// Check if migration already in progress
			mm.mu.RLock()
			_, inProgress := mm.migrations[rule.ServiceName]
			mm.mu.RUnlock()

			if !inProgress {
				log.Printf("Triggering migration of %s due to rule: %+v", rule.ServiceName, rule.Trigger)
				if err := mm.StartMigration(ctx, rule); err != nil {
					log.Printf("Failed to start migration of %s: %v", rule.ServiceName, err)
				}
			}
		}
	}
}

// GetActiveMigrations returns all active migrations
func (mm *MigrationManager) GetActiveMigrations() []*Migration {
	mm.mu.RLock()
	defer mm.mu.RUnlock()

	result := make([]*Migration, 0, len(mm.migrations))
	for _, migration := range mm.migrations {
		if migration.Status == MigrationStatusRunning || migration.Status == MigrationStatusPending {
			result = append(result, &Migration{
				ServiceName: migration.ServiceName,
				SourceNode:  migration.SourceNode,
				TargetNode:  migration.TargetNode,
				Status:      migration.Status,
				StartedAt:   migration.StartedAt,
				CompletedAt: migration.CompletedAt,
				Error:       migration.Error,
			})
		}
	}

	return result
}
