package gossip

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGossipDelegate_ChunkedBroadcastRoundTrip(t *testing.T) {
	senderState := NewClusterState()
	senderState.UpdateNode(&NodeMetadata{
		Name:        "node-a",
		PublicIP:    "10.0.0.1",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
	})

	for i := 0; i < 6; i++ {
		serviceName := fmt.Sprintf("service-%d", i)
		senderState.UpdateServiceHealth(&ServiceHealth{
			ServiceName: serviceName,
			NodeName:    "node-a",
			Healthy:     true,
			Endpoints: map[string]string{
				"http": fmt.Sprintf("http://%s:8080", serviceName),
			},
			Networks: []string{"frontend", "default"},
		})
	}
	senderState.UpdateServiceLease("service-5", &ServiceLease{
		NodeName:   "node-a",
		Term:       12,
		LeaseID:    "lease-12",
		ObservedAt: time.Now().UTC(),
	})

	sender := NewGossipDelegate("node-a", senderState)
	receiverState := NewClusterState()
	receiver := NewGossipDelegate("node-b", receiverState)

	messages := sender.GetBroadcasts(32, 200)
	require.Greater(t, len(messages), 1, "state should be chunked for this test")

	for i := len(messages) - 1; i >= 0; i-- {
		receiver.NotifyMsg(messages[i])
	}

	health, exists := receiverState.GetServiceHealth("service-5", "node-a")
	require.True(t, exists)
	assert.True(t, health.Healthy)
	assert.Equal(t, "http://service-5:8080", health.Endpoints["http"])

	lease, exists := receiverState.GetServiceLease("service-5")
	require.True(t, exists)
	assert.Equal(t, "node-a", lease.NodeName)
	assert.Equal(t, uint64(12), lease.Term)
	assert.Equal(t, "lease-12", lease.LeaseID)
}
