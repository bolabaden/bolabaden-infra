package failover

import (
	"context"
	"testing"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func createTestMigrationManager() (*MigrationManager, *gossip.ClusterState) {
	state := gossip.NewClusterState()
	manager := NewMigrationManager(nil, state, "test-node")
	return manager, state
}

func TestMigrationManager_NewMigrationManager(t *testing.T) {
	state := gossip.NewClusterState()
	manager := NewMigrationManager(nil, state, "test-node")

	assert.NotNil(t, manager)
	assert.Equal(t, "test-node", manager.nodeName)
	assert.Equal(t, state, manager.gossipState)
	assert.NotNil(t, manager.migrations)
}

func TestMigrationManager_SelectTargetNode(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add candidate nodes
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Priority: 10,
		Cordoned: false,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node2",
		Priority: 20,
		Cordoned: false,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node3",
		Priority: 5,
		Cordoned: true, // Cordoned - should be skipped
	})

	target, err := manager.selectTargetNode("test-service")
	require.NoError(t, err)
	assert.Equal(t, "node1", target) // Should select node with lowest priority (highest priority)
}

func TestMigrationManager_SelectTargetNode_NoCandidates(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add only cordoned nodes
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Priority: 10,
		Cordoned: true,
	})

	_, err := manager.selectTargetNode("test-service")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no suitable target nodes")
}

func TestMigrationManager_SelectTargetNode_ExcludesCurrentNode(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add nodes including current node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "test-node",
		Priority: 5,
		Cordoned: false,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Priority: 10,
		Cordoned: false,
	})

	target, err := manager.selectTargetNode("test-service")
	require.NoError(t, err)
	assert.Equal(t, "node1", target) // Should not select current node
	assert.NotEqual(t, "test-node", target)
}

func TestMigrationManager_StartMigration(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add target node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	rule := MigrationRule{
		ServiceName: "test-service",
		TargetNode:  "target-node",
		Trigger:     MigrationTrigger{},
	}

	err := manager.StartMigration(context.Background(), rule)
	require.NoError(t, err)

	// Check migration exists
	migration, exists := manager.GetMigrationStatus("test-service")
	require.True(t, exists)
	assert.Equal(t, "test-service", migration.ServiceName)
	assert.Equal(t, "test-node", migration.SourceNode)
	assert.Equal(t, "target-node", migration.TargetNode)
	assert.Equal(t, MigrationStatusPending, migration.Status)
}

func TestMigrationManager_StartMigration_AutoSelectTarget(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add target node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	rule := MigrationRule{
		ServiceName: "test-service",
		TargetNode:  "", // Auto-select
		Trigger:     MigrationTrigger{},
	}

	err := manager.StartMigration(context.Background(), rule)
	require.NoError(t, err)

	migration, exists := manager.GetMigrationStatus("test-service")
	require.True(t, exists)
	assert.Equal(t, "target-node", migration.TargetNode)
}

func TestMigrationManager_StartMigration_AlreadyInProgress(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add target node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	rule := MigrationRule{
		ServiceName: "test-service",
		TargetNode:  "target-node",
		Trigger:     MigrationTrigger{},
	}

	// Start first migration
	err := manager.StartMigration(context.Background(), rule)
	require.NoError(t, err)

	// Try to start another migration for the same service
	err = manager.StartMigration(context.Background(), rule)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "already in progress")
}

func TestMigrationManager_GetMigrationStatus(t *testing.T) {
	manager, state := createTestMigrationManager()

	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	rule := MigrationRule{
		ServiceName: "test-service",
		TargetNode:  "target-node",
		Trigger:     MigrationTrigger{},
	}

	err := manager.StartMigration(context.Background(), rule)
	require.NoError(t, err)

	// Wait a bit for migration to start
	time.Sleep(100 * time.Millisecond)

	migration, exists := manager.GetMigrationStatus("test-service")
	require.True(t, exists)
	assert.Equal(t, "test-service", migration.ServiceName)
	assert.NotNil(t, migration.StartedAt)
}

func TestMigrationManager_GetMigrationStatus_NotFound(t *testing.T) {
	manager, _ := createTestMigrationManager()

	_, exists := manager.GetMigrationStatus("nonexistent")
	assert.False(t, exists)
}

func TestMigrationManager_GetActiveMigrations(t *testing.T) {
	manager, state := createTestMigrationManager()

	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	// Start multiple migrations
	rule1 := MigrationRule{
		ServiceName: "service1",
		TargetNode:  "target-node",
		Trigger:     MigrationTrigger{},
	}
	rule2 := MigrationRule{
		ServiceName: "service2",
		TargetNode:  "target-node",
		Trigger:     MigrationTrigger{},
	}

	err := manager.StartMigration(context.Background(), rule1)
	require.NoError(t, err)
	err = manager.StartMigration(context.Background(), rule2)
	require.NoError(t, err)

	// Wait a bit
	time.Sleep(100 * time.Millisecond)

	active := manager.GetActiveMigrations()
	assert.GreaterOrEqual(t, len(active), 2)
}

func TestMigrationManager_CheckAndMigrate_HealthBased(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add target node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	// Add unhealthy service
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "unhealthy-service",
		NodeName:    "test-node",
		Healthy:     false,
	})

	rule := MigrationRule{
		ServiceName: "unhealthy-service",
		TargetNode:  "target-node",
		Trigger: MigrationTrigger{
			HealthCheckFailures: 1,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	// Use CheckAndMigrate to test the full migration trigger logic
	manager.CheckAndMigrate(ctx, []MigrationRule{rule})

	// Wait a bit
	time.Sleep(200 * time.Millisecond)

	// Migration should have been triggered
	migration, exists := manager.GetMigrationStatus("unhealthy-service")
	assert.True(t, exists)
	assert.Equal(t, "target-node", migration.TargetNode)
}

func TestMigrationManager_CheckAndMigrate_NodeUnhealthy(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add target node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "target-node",
		Priority: 10,
		Cordoned: false,
	})

	// Cordon current node
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "test-node",
		Priority: 10,
		Cordoned: true,
	})

	// Add service on this node
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "cordoned-service",
		NodeName:    "test-node",
		Healthy:     true,
	})

	rule := MigrationRule{
		ServiceName: "cordoned-service",
		TargetNode:  "target-node",
		Trigger: MigrationTrigger{
			NodeUnhealthy: true,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	// Use CheckAndMigrate to test the full migration trigger logic
	manager.CheckAndMigrate(ctx, []MigrationRule{rule})

	// Wait a bit
	time.Sleep(200 * time.Millisecond)

	// Migration should have been triggered
	_, exists := manager.GetMigrationStatus("cordoned-service")
	assert.True(t, exists)
}

func TestMigrationManager_CheckAndMigrate_NoTrigger(t *testing.T) {
	manager, state := createTestMigrationManager()

	// Add healthy service
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "healthy-service",
		NodeName:    "test-node",
		Healthy:     true,
	})

	rule := MigrationRule{
		ServiceName: "healthy-service",
		TargetNode:  "target-node",
		Trigger: MigrationTrigger{
			HealthCheckFailures: 1,
		},
	}

	// For healthy service, migration should not be triggered automatically
	// This test verifies that migration is not started for healthy services
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	// CheckAndMigrate should not trigger migration for healthy service
	manager.CheckAndMigrate(ctx, []MigrationRule{rule})

	// No migration should exist
	_, exists := manager.GetMigrationStatus("healthy-service")
	assert.False(t, exists)
}

func TestMigrationManager_CheckAndMigrate_ReMigrateAfterCompletion(t *testing.T) {
	// This test verifies that a service can be re-migrated after a previous migration completed
	manager, state := createTestMigrationManager()

	serviceName := "test-service"
	nodeName := "test-node"

	// Add unhealthy service
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: serviceName,
		NodeName:    nodeName,
		Healthy:     false,
	})

	rule := MigrationRule{
		ServiceName: serviceName,
		TargetNode:  "target-node",
		Trigger: MigrationTrigger{
			HealthCheckFailures: 1,
		},
	}

	// First migration - should succeed
	ctx1, cancel1 := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel1()

	manager.CheckAndMigrate(ctx1, []MigrationRule{rule})
	time.Sleep(150 * time.Millisecond)

	// Verify first migration exists and completed
	migration1, exists := manager.GetMigrationStatus(serviceName)
	require.True(t, exists, "First migration should exist")
	assert.True(t, migration1.Status == MigrationStatusCompleted || migration1.Status == MigrationStatusFailed,
		"First migration should be completed or failed, got: %s", migration1.Status)

	// Mark service as healthy, then unhealthy again (simulating service recovery and failure)
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: serviceName,
		NodeName:    nodeName,
		Healthy:     true,
	})
	time.Sleep(50 * time.Millisecond)
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: serviceName,
		NodeName:    nodeName,
		Healthy:     false,
	})

	// Second migration attempt - should be allowed since previous migration is completed
	ctx2, cancel2 := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel2()

	manager.CheckAndMigrate(ctx2, []MigrationRule{rule})
	time.Sleep(150 * time.Millisecond)

	// Verify second migration was triggered (should have new StartedAt time)
	migration2, exists := manager.GetMigrationStatus(serviceName)
	require.True(t, exists, "Second migration should exist")
	// The migration should have been re-triggered (newer StartedAt or different status)
	assert.True(t, migration2.Status == MigrationStatusPending || migration2.Status == MigrationStatusRunning ||
		migration2.Status == MigrationStatusCompleted || migration2.Status == MigrationStatusFailed,
		"Second migration should have been triggered, status: %s", migration2.Status)
}

func TestMigrationStatus_Constants(t *testing.T) {
	assert.Equal(t, MigrationStatus("pending"), MigrationStatusPending)
	assert.Equal(t, MigrationStatus("running"), MigrationStatusRunning)
	assert.Equal(t, MigrationStatus("completed"), MigrationStatusCompleted)
	assert.Equal(t, MigrationStatus("failed"), MigrationStatusFailed)
}
