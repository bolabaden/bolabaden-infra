package gossip

import (
	"fmt"
	"net"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func reserveTestPort(t *testing.T) int {
	t.Helper()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	defer listener.Close()

	return listener.Addr().(*net.TCPAddr).Port
}

func createTestCluster(t *testing.T, nodeName string, bindPort int, seedNodes []string) *GossipCluster {
	t.Helper()

	cluster, err := NewGossipCluster(&Config{
		NodeName:     nodeName,
		BindAddr:     "127.0.0.1",
		BindPort:     bindPort,
		PublicIP:     fmt.Sprintf("10.0.0.%d", bindPort%250+1),
		TailscaleIP:  "127.0.0.1",
		Priority:     10,
		Capabilities: []string{"proxy", "media"},
		SeedNodes:    seedNodes,
	})
	require.NoError(t, err)

	t.Cleanup(func() {
		_ = cluster.Leave()
		_ = cluster.Shutdown()
	})

	return cluster
}

func TestGossipCluster_ServiceAndLeaseConvergenceAcrossNodes(t *testing.T) {
	portA := reserveTestPort(t)
	portB := reserveTestPort(t)

	nodeA := createTestCluster(t, "node-a", portA, nil)
	nodeB := createTestCluster(t, "node-b", portB, []string{fmt.Sprintf("127.0.0.1:%d", portA)})

	require.Eventually(t, func() bool {
		return len(nodeA.GetMembers()) == 2 && len(nodeB.GetMembers()) == 2
	}, 5*time.Second, 100*time.Millisecond)

	nodeA.BroadcastServiceHealth("grafana", true, map[string]string{"http": "http://grafana:3000"}, []string{"frontend"})
	nodeA.GetState().UpdateServiceLease("grafana", &ServiceLease{
		NodeName:   "node-a",
		Term:       9,
		LeaseID:    "lease-9",
		ObservedAt: time.Now().UTC(),
	})
	nodeA.UpdateNodeMetadata(true, []string{"proxy", "media", "gpu"})

	require.Eventually(t, func() bool {
		health, exists := nodeB.GetState().GetServiceHealth("grafana", "node-a")
		if !exists || !health.Healthy {
			return false
		}

		lease, exists := nodeB.GetState().GetServiceLease("grafana")
		if !exists || lease.NodeName != "node-a" || lease.LeaseID != "lease-9" {
			return false
		}

		node, exists := nodeB.GetState().GetNode("node-a")
		if !exists || !node.Cordoned {
			return false
		}

		return len(node.Capabilities) == 3
	}, 5*time.Second, 100*time.Millisecond)

	health, exists := nodeB.GetState().GetServiceHealth("grafana", "node-a")
	require.True(t, exists)
	assert.Equal(t, "http://grafana:3000", health.Endpoints["http"])
	assert.ElementsMatch(t, []string{"frontend"}, health.Networks)

	healthyNodes := nodeB.GetState().GetHealthyServiceNodes("grafana")
	assert.Empty(t, healthyNodes, "cordoned nodes should not be treated as healthy routing targets")
}
