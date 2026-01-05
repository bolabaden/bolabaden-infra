package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/bolabaden/my-media-stack/infra/failover"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// End-to-end tests that test complete workflows
func TestE2E_NodeJoinAndServiceDiscovery(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Simulate node joining
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "new-node",
		PublicIP:    "10.0.0.1",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
		Cordoned:    false,
	})

	// Simulate service being discovered on that node
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "web-service",
		NodeName:    "new-node",
		Healthy:     true,
		Endpoints:   map[string]string{"http": "http://web-service:8080"},
		Networks:    []string{"default"},
	})

	// Verify via API
	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/nodes/new-node":
			server.handleNode(w, r)
		case "/api/v1/services/web-service":
			server.handleService(w, r)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer testServer.Close()

	// Check node exists
	resp, err := http.Get(testServer.URL + "/api/v1/nodes/new-node")
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var nodeResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&nodeResp)
	assert.Equal(t, "new-node", nodeResp["name"])

	// Check service exists
	resp, err = http.Get(testServer.URL + "/api/v1/services/web-service")
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var serviceResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&serviceResp)
	assert.Equal(t, "web-service", serviceResp["service_name"])
}

func TestE2E_ServiceHealthChangePropagation(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	_ = NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/ws" {
			wsServer.HandleWebSocket(w, r)
		} else {
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer testServer.Close()

	// Connect WebSocket client
	url := "ws" + testServer.URL[4:] + "/ws"
	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Simulate service health change
	wsServer.BroadcastServiceHealthChange("test-service", "test-node", false)

	// Verify WebSocket receives the update
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	json.Unmarshal(message, &update)
	assert.Equal(t, "service_health_change", update["type"])
	assert.Equal(t, "test-service", update["service_name"])
	assert.Equal(t, false, update["healthy"])
}

func TestE2E_FailoverScenario(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	_ = NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	state := gossipCluster.GetState()

	// Setup: Service running on node1
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

	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "critical-service",
		NodeName:    "node1",
		Healthy:     true,
	})

	// Scenario: node1 becomes unhealthy (cordoned)
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Priority: 10,
		Cordoned: true, // Node is now cordoned
	})

	// Trigger migration
	rule := failover.MigrationRule{
		ServiceName: "critical-service",
		TargetNode:  "node2",
		Trigger: failover.MigrationTrigger{
			NodeUnhealthy: true,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	// Use CheckAndMigrate to test the full migration trigger logic
	// In a real scenario, this would be called via MonitorAndMigrate
	migrationManager.CheckAndMigrate(ctx, []failover.MigrationRule{rule})

	// Wait for migration
	time.Sleep(300 * time.Millisecond)

	// Verify migration was triggered
	migration, exists := migrationManager.GetMigrationStatus("critical-service")
	require.True(t, exists)
	assert.Equal(t, "node2", migration.TargetNode)

	// Verify via API
	apiServer := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)
	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/migrations":
			apiServer.handleMigrations(w, r)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer testServer.Close()

	resp, err := http.Get(testServer.URL + "/api/v1/migrations")
	require.NoError(t, err)
	defer resp.Body.Close()

	var migrationsResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&migrationsResp)
	migrations := migrationsResp["migrations"].([]interface{})
	assert.Greater(t, len(migrations), 0)
}

func TestE2E_MultipleClientsWebSocketUpdates(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	_ = NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/ws" {
			wsServer.HandleWebSocket(w, r)
		}
	}))
	defer testServer.Close()

	url := "ws" + testServer.URL[4:] + "/ws"
	dialer := websocket.Dialer{}

	// Connect multiple clients
	var clients []*websocket.Conn
	var wg sync.WaitGroup
	receivedMessages := make(map[int][]map[string]interface{})

	for i := 0; i < 5; i++ {
		conn, _, err := dialer.Dial(url, nil)
		require.NoError(t, err)
		clients = append(clients, conn)

		// Discard initial state
		time.Sleep(50 * time.Millisecond)
		conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
		conn.ReadMessage()

		// Start reading messages
		wg.Add(1)
		clientIdx := i
		go func() {
			defer wg.Done()
			messages := []map[string]interface{}{}
			for {
				conn.SetReadDeadline(time.Now().Add(2 * time.Second))
				_, msg, err := conn.ReadMessage()
				if err != nil {
					break
				}
				var update map[string]interface{}
				if json.Unmarshal(msg, &update) == nil {
					messages = append(messages, update)
				}
			}
			receivedMessages[clientIdx] = messages
		}()
	}

	// Wait for all clients to be ready
	time.Sleep(200 * time.Millisecond)

	// Broadcast multiple events
	wsServer.BroadcastNodeJoin("node1")
	time.Sleep(100 * time.Millisecond)
	wsServer.BroadcastServiceHealthChange("service1", "node1", true)
	time.Sleep(100 * time.Millisecond)
	wsServer.BroadcastLeaderChange("node1")

	// Close connections and wait for reads to complete
	for _, conn := range clients {
		conn.Close()
	}
	wg.Wait()

	// Verify all clients received the broadcasts
	for i := 0; i < 5; i++ {
		messages := receivedMessages[i]
		assert.GreaterOrEqual(t, len(messages), 3, "Client %d should receive at least 3 messages", i)
	}
}
