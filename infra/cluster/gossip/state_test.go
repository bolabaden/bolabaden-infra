package gossip

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpdateServiceHealth_PreservesCurrentLease(t *testing.T) {
	state := NewClusterState()
	observedAt := time.Now().UTC()

	state.UpdateServiceHealth(&ServiceHealth{
		ServiceName: "grafana",
		NodeName:    "node-a",
		Healthy:     true,
		CurrentLease: &ServiceLease{
			NodeName:   "node-a",
			Term:       3,
			LeaseID:    "lease-3",
			ObservedAt: observedAt,
		},
	})

	state.UpdateServiceHealth(&ServiceHealth{
		ServiceName: "grafana",
		NodeName:    "node-a",
		Healthy:     false,
	})

	health, exists := state.GetServiceHealth("grafana", "node-a")
	require.True(t, exists)
	require.NotNil(t, health.CurrentLease)
	assert.Equal(t, "node-a", health.CurrentLease.NodeName)
	assert.Equal(t, uint64(3), health.CurrentLease.Term)
	assert.Equal(t, "lease-3", health.CurrentLease.LeaseID)
	assert.True(t, health.CurrentLease.ObservedAt.Equal(observedAt))
}

func TestUpdateServiceLease_UpdatesAllKnownInstances(t *testing.T) {
	state := NewClusterState()
	state.UpdateServiceHealth(&ServiceHealth{ServiceName: "grafana", NodeName: "node-a", Healthy: true})
	state.UpdateServiceHealth(&ServiceHealth{ServiceName: "grafana", NodeName: "node-b", Healthy: false})
	state.UpdateServiceHealth(&ServiceHealth{ServiceName: "prometheus", NodeName: "node-a", Healthy: true})

	observedAt := time.Now().UTC()
	state.UpdateServiceLease("grafana", &ServiceLease{
		NodeName:   "node-b",
		Term:       9,
		LeaseID:    "lease-9",
		ObservedAt: observedAt,
	})

	instances := state.GetServiceInstances("grafana")
	require.Len(t, instances, 2)
	for _, health := range instances {
		require.NotNil(t, health.CurrentLease)
		assert.Equal(t, "node-b", health.CurrentLease.NodeName)
		assert.Equal(t, uint64(9), health.CurrentLease.Term)
		assert.Equal(t, "lease-9", health.CurrentLease.LeaseID)
		assert.True(t, health.CurrentLease.ObservedAt.Equal(observedAt))
	}

	other, exists := state.GetServiceHealth("prometheus", "node-a")
	require.True(t, exists)
	assert.Nil(t, other.CurrentLease)
}

func TestGetServiceLease_ReturnsMostRecentObservedLease(t *testing.T) {
	state := NewClusterState()
	older := time.Now().UTC().Add(-1 * time.Minute)
	newer := time.Now().UTC()

	state.UpdateServiceHealth(&ServiceHealth{
		ServiceName: "grafana",
		NodeName:    "node-a",
		Healthy:     true,
		CurrentLease: &ServiceLease{
			NodeName:   "node-a",
			Term:       4,
			LeaseID:    "lease-old",
			ObservedAt: older,
		},
	})
	state.UpdateServiceHealth(&ServiceHealth{
		ServiceName: "grafana",
		NodeName:    "node-b",
		Healthy:     true,
		CurrentLease: &ServiceLease{
			NodeName:   "node-b",
			Term:       5,
			LeaseID:    "lease-new",
			ObservedAt: newer,
		},
	})

	lease, exists := state.GetServiceLease("grafana")
	require.True(t, exists)
	require.NotNil(t, lease)
	assert.Equal(t, "node-b", lease.NodeName)
	assert.Equal(t, uint64(5), lease.Term)
	assert.Equal(t, "lease-new", lease.LeaseID)
	assert.True(t, lease.ObservedAt.Equal(newer))
}

func TestRemoveNode_PreservesServicesButMarksNodeOffline(t *testing.T) {
	state := NewClusterState()
	state.UpdateNode(&NodeMetadata{Name: "node-a", Priority: 10})
	state.UpdateServiceHealth(&ServiceHealth{
		ServiceName: "grafana",
		NodeName:    "node-a",
		Healthy:     true,
	})

	state.RemoveNode("node-a")

	node, exists := state.GetNode("node-a")
	require.True(t, exists)
	assert.False(t, node.Online)
	assert.True(t, node.Cordoned)

	health, exists := state.GetServiceHealth("grafana", "node-a")
	require.True(t, exists)
	assert.False(t, health.Healthy)
	assert.GreaterOrEqual(t, health.ConsecutiveFailures, 1)

	assert.Empty(t, state.GetHealthyServiceNodes("grafana"))
}
