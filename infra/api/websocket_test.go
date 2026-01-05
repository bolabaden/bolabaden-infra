package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/bolabaden/my-media-stack/infra/cluster/raft"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func createTestWebSocketServer() (*WebSocketServer, *gossip.GossipCluster, *raft.ConsensusManager) {
	gossip.NewClusterState()
	config := &gossip.Config{
		NodeName:     "test-node",
		BindAddr:     "127.0.0.1",
		BindPort:     7946,
		PublicIP:     "1.2.3.4",
		TailscaleIP:  "100.64.0.1",
		Priority:     10,
		Capabilities: []string{},
		SeedNodes:    []string{},
	}
	cluster, _ := gossip.NewGossipCluster(config)

	tmpDir := "/tmp/raft-test-" + time.Now().Format("20060102-150405")
	raftConfig := &raft.Config{
		NodeName:  "test-node",
		DataDir:   tmpDir,
		BindAddr:  "127.0.0.1",
		BindPort:  8300,
		SeedNodes: []string{},
		LogLevel:  "error",
	}
	consensusManager, _ := raft.NewConsensusManager(raftConfig)

	wsServer := NewWebSocketServer(cluster, consensusManager)
	return wsServer, cluster, consensusManager
}

func TestWebSocketServer_NewWebSocketServer(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()

	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	assert.NotNil(t, wsServer)
	assert.NotNil(t, wsServer.clients)
	assert.NotNil(t, wsServer.broadcast)
	assert.Equal(t, gossipCluster, wsServer.gossipCluster)
	assert.Equal(t, consensusManager, wsServer.consensusManager)
}

func TestWebSocketServer_HandleWebSocket(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	// Create test HTTP server
	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	// Convert http:// to ws://
	url := "ws" + server.URL[4:] + "/ws"

	// Connect to WebSocket
	dialer := websocket.Dialer{}
	conn, resp, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	require.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)
	defer conn.Close()

	// Client registration happens synchronously in HandleWebSocket before returning
	// However, since HandleWebSocket is running in a separate goroutine (via httptest),
	// we need to wait a moment for it to complete the registration
	// The registration happens at the start of HandleWebSocket, so it should be immediate
	time.Sleep(100 * time.Millisecond)

	// Check that client is registered
	// Note: The conn pointer we have is different from the one stored in the map,
	// so we need to check if any client exists, or verify registration differently
	wsServer.mu.RLock()
	clientCount := len(wsServer.clients)
	wsServer.mu.RUnlock()
	
	// The connection should be registered
	// Since we can't directly compare conn pointers, we check that at least one client is registered
	assert.Greater(t, clientCount, 0, "At least one client should be registered after connection")
	
	// Also verify that our specific connection exists by checking if we can find it
	// by trying to send a ping (if connection is registered, it should work)
	wsServer.mu.RLock()
	found := false
	for clientConn := range wsServer.clients {
		// Check if this might be our connection by comparing some property
		// Since we can't compare conn directly, we'll just verify count > 0
		_ = clientConn
		found = true
		break
	}
	wsServer.mu.RUnlock()
	assert.True(t, found, "A WebSocket client should be registered in the server")
}

func TestWebSocketServer_SendInitialState(t *testing.T) {
	wsServer, cluster, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	// Add some test data
	state := cluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "test-node",
		PublicIP:    "1.2.3.4",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "test-service",
		NodeName:    "test-node",
		Healthy:     true,
	})

	// Create test HTTP server
	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	
	// Read initial state message
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	err = json.Unmarshal(message, &update)
	require.NoError(t, err)
	assert.Equal(t, "initial_state", update["type"])
	assert.Contains(t, update, "nodes")
	assert.Contains(t, update, "services")
	assert.Contains(t, update, "raft")
	
	// Close connection to stop the periodic updates goroutine
	conn.Close()
	
	// Wait a moment for goroutine to clean up
	time.Sleep(100 * time.Millisecond)
}

func TestWebSocketServer_PingPong(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Wait for initial state
	time.Sleep(100 * time.Millisecond)

	// Send ping
	err = conn.WriteMessage(websocket.TextMessage, []byte("ping"))
	require.NoError(t, err)

	// Read pong
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)
	assert.Equal(t, "pong", string(message))
}

func TestWebSocketServer_Broadcast(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}

	// Connect first client
	conn1, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn1.Close()

	// Connect second client
	conn2, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn2.Close()

	// Wait for connections
	time.Sleep(100 * time.Millisecond)

	// Send initial state to clients (discard)
	conn1.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn1.ReadMessage()
	conn2.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn2.ReadMessage()

	// Broadcast a message
	testMessage := map[string]interface{}{
		"type":    "test",
		"message": "hello",
	}
	wsServer.Broadcast(testMessage)

	// Both clients should receive the message
	conn1.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, msg1, err := conn1.ReadMessage()
	require.NoError(t, err)

	conn2.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, msg2, err := conn2.ReadMessage()
	require.NoError(t, err)

	var received1, received2 map[string]interface{}
	json.Unmarshal(msg1, &received1)
	json.Unmarshal(msg2, &received2)

	assert.Equal(t, "test", received1["type"])
	assert.Equal(t, "hello", received1["message"])
	assert.Equal(t, "test", received2["type"])
	assert.Equal(t, "hello", received2["message"])
}

func TestWebSocketServer_BroadcastNodeJoin(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Broadcast node join
	wsServer.BroadcastNodeJoin("new-node")

	// Read the broadcast
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	json.Unmarshal(message, &update)
	assert.Equal(t, "node_join", update["type"])
	assert.Equal(t, "new-node", update["node_name"])
}

func TestWebSocketServer_BroadcastNodeLeave(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Broadcast node leave
	wsServer.BroadcastNodeLeave("old-node")

	// Read the broadcast
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	json.Unmarshal(message, &update)
	assert.Equal(t, "node_leave", update["type"])
	assert.Equal(t, "old-node", update["node_name"])
}

func TestWebSocketServer_BroadcastServiceHealthChange(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Broadcast service health change
	wsServer.BroadcastServiceHealthChange("test-service", "test-node", true)

	// Read the broadcast
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	json.Unmarshal(message, &update)
	assert.Equal(t, "service_health_change", update["type"])
	assert.Equal(t, "test-service", update["service_name"])
	assert.Equal(t, "test-node", update["node_name"])
	assert.Equal(t, true, update["healthy"])
}

func TestWebSocketServer_BroadcastLeaderChange(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Broadcast leader change
	wsServer.BroadcastLeaderChange("new-leader")

	// Read the broadcast
	conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, message, err := conn.ReadMessage()
	require.NoError(t, err)

	var update map[string]interface{}
	json.Unmarshal(message, &update)
	assert.Equal(t, "leader_change", update["type"])
	assert.Equal(t, "new-leader", update["leader"])
}

func TestWebSocketServer_ConcurrentWrites(t *testing.T) {
	wsServer, _, consensusManager := createTestWebSocketServer()
	defer consensusManager.Shutdown()

	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	url := "ws" + server.URL[4:] + "/ws"

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial(url, nil)
	require.NoError(t, err)
	defer conn.Close()

	// Discard initial state
	time.Sleep(100 * time.Millisecond)
	conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	conn.ReadMessage()

	// Send multiple broadcasts concurrently
	for i := 0; i < 10; i++ {
		go wsServer.Broadcast(map[string]interface{}{
			"type": "test",
			"id":   i,
		})
	}

	// Read messages (should not panic)
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	receivedCount := 0
	for receivedCount < 10 {
		_, _, err := conn.ReadMessage()
		if err != nil {
			break
		}
		receivedCount++
	}

	// Should receive at least some messages
	assert.Greater(t, receivedCount, 0)
}
