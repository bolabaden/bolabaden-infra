package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/bolabaden/my-media-stack/infra/cluster/raft"
	"github.com/bolabaden/my-media-stack/infra/failover"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var (
	portCounter  int64
	portCounterMu sync.Mutex
)

func getNextPort() int {
	portCounterMu.Lock()
	defer portCounterMu.Unlock()
	portCounter++
	basePort := 9000
	return basePort + int(portCounter%1000) // Use ports 9000-9999
}

// Mock helpers
func createTestGossipCluster() *gossip.GossipCluster {
	gossipPort := getNextPort()
	nodeID := fmt.Sprintf("%d-%d", time.Now().UnixNano(), gossipPort)
	config := &gossip.Config{
		NodeName:     "test-node-" + nodeID,
		BindAddr:     "127.0.0.1",
		BindPort:     gossipPort,
		PublicIP:     "1.2.3.4",
		TailscaleIP:  "100.64.0.1",
		Priority:     10,
		Capabilities: []string{},
		SeedNodes:    []string{},
	}
	cluster, _ := gossip.NewGossipCluster(config)
	return cluster
}

func createTestConsensusManager() *raft.ConsensusManager {
	// Create a temporary directory for Raft data with unique name
	raftPort := getNextPort()
	nodeID := fmt.Sprintf("%d-%d", time.Now().UnixNano(), raftPort)
	tmpDir := "/tmp/raft-test-" + nodeID
	config := &raft.Config{
		NodeName:  "test-node-" + nodeID,
		DataDir:   tmpDir,
		BindAddr:  "127.0.0.1",
		BindPort:  raftPort,
		SeedNodes: []string{},
		LogLevel:  "error", // Reduce noise in tests
	}
	manager, _ := raft.NewConsensusManager(config)
	return manager
}

func createTestMigrationManager() *failover.MigrationManager {
	state := gossip.NewClusterState()
	return failover.NewMigrationManager(nil, state, "test-node")
}

func TestServer_NewServer(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)

	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)
	assert.NotNil(t, server)
	assert.Equal(t, 8080, server.port)
	assert.Equal(t, gossipCluster, server.gossipCluster)
	assert.Equal(t, consensusManager, server.consensusManager)
	assert.Equal(t, migrationManager, server.migrationManager)
	assert.Equal(t, wsServer, server.wsServer)
}

func TestServer_HandleHealth(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	server.handleHealth(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Equal(t, "healthy", response["status"])
	assert.Contains(t, response, "timestamp")
}

func TestServer_HandleStatus(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add a test node
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "test-node",
		PublicIP:    "1.2.3.4",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/status", nil)
	w := httptest.NewRecorder()

	server.handleStatus(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Equal(t, "constellation", response["service"])
	assert.Contains(t, response, "nodes")
	assert.Contains(t, response, "services")
	assert.Contains(t, response, "raft_leader")
	assert.Contains(t, response, "cluster_version")
}

func TestServer_HandleNodes(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add test nodes
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "node1",
		PublicIP:    "1.2.3.4",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "node2",
		PublicIP:    "5.6.7.8",
		TailscaleIP: "100.64.0.2",
		Priority:    20,
		Cordoned:    true,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/nodes", nil)
	w := httptest.NewRecorder()

	server.handleNodes(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "nodes")

	nodes := response["nodes"].([]interface{})
	assert.Len(t, nodes, 2)
}

func TestServer_HandleNode(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add a test node
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:        "test-node",
		PublicIP:    "1.2.3.4",
		TailscaleIP: "100.64.0.1",
		Priority:    10,
	})

	// Add a service to this node
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "test-service",
		NodeName:    "test-node",
		Healthy:     true,
		Endpoints:   map[string]string{"http": "http://test-service:8080"},
		Networks:    []string{"network1"},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/test-node", nil)
	w := httptest.NewRecorder()

	server.handleNode(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Equal(t, "test-node", response["name"])
	assert.Equal(t, "1.2.3.4", response["public_ip"])
	assert.Contains(t, response, "services")
}

func TestServer_HandleNode_NotFound(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/nodes/nonexistent", nil)
	w := httptest.NewRecorder()

	server.handleNode(w, req)

	assert.Equal(t, http.StatusNotFound, w.Code)
}

func TestServer_HandleServices(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add service health entries
	state := gossipCluster.GetState()
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "service1",
		NodeName:    "node1",
		Healthy:     true,
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "service1",
		NodeName:    "node2",
		Healthy:     false,
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "service2",
		NodeName:    "node1",
		Healthy:     true,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/services", nil)
	w := httptest.NewRecorder()

	server.handleServices(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "services")

	services := response["services"].([]interface{})
	assert.GreaterOrEqual(t, len(services), 2)
}

func TestServer_HandleService(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add service health entries
	state := gossipCluster.GetState()
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "test-service",
		NodeName:    "node1",
		Healthy:     true,
		Endpoints:   map[string]string{"http": "http://test-service:8080"},
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "test-service",
		NodeName:    "node2",
		Healthy:     false,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/services/test-service", nil)
	w := httptest.NewRecorder()

	server.handleService(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Equal(t, "test-service", response["service_name"])
	assert.Contains(t, response, "instances")
	assert.Contains(t, response, "healthy_count")
}

func TestServer_HandleRaftStatus(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/raft/status", nil)
	w := httptest.NewRecorder()

	server.handleRaftStatus(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "is_leader")
	assert.Contains(t, response, "leader")
}

func TestServer_HandleRaftLeader(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/raft/leader", nil)
	w := httptest.NewRecorder()

	server.handleRaftLeader(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "leader")
}

func TestServer_HandleMetrics(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Add some test data
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Cordoned: false,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node2",
		Cordoned: true,
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "service1",
		NodeName:    "node1",
		Healthy:     true,
	})
	state.UpdateServiceHealth(&gossip.ServiceHealth{
		ServiceName: "service2",
		NodeName:    "node2",
		Healthy:     false,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/metrics", nil)
	w := httptest.NewRecorder()

	server.handleMetrics(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "nodes")
	assert.Contains(t, response, "services")
	assert.Contains(t, response, "raft")
}

func TestServer_HandleMigrations(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/migrations", nil)
	w := httptest.NewRecorder()

	server.handleMigrations(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Contains(t, response, "migrations")
}

func TestServer_HandleMigrations_NoManager(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, nil, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/migrations", nil)
	w := httptest.NewRecorder()

	server.handleMigrations(w, req)

	assert.Equal(t, http.StatusServiceUnavailable, w.Code)
}

func TestServer_HandleMigration(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/migrations/test-service", nil)
	w := httptest.NewRecorder()

	server.handleMigration(w, req)

	// Should return 404 if migration doesn't exist
	assert.Equal(t, http.StatusNotFound, w.Code)
}

func TestServer_HandleMigration_NoManager(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, nil, wsServer, 8080)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/migrations/test-service", nil)
	w := httptest.NewRecorder()

	server.handleMigration(w, req)

	assert.Equal(t, http.StatusServiceUnavailable, w.Code)
}
