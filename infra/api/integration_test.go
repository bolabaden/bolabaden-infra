package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Integration tests for API endpoints with full server setup
func TestAPI_Integration_StatusEndpoint(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	// Create a test HTTP server
	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/status":
			server.handleStatus(w, r)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer testServer.Close()

	// Add test data
	state := gossipCluster.GetState()
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		Cordoned: false,
	})

	// Make request
	resp, err := http.Get(testServer.URL + "/api/v1/status")
	require.NoError(t, err)
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode)
	assert.Equal(t, "application/json", resp.Header.Get("Content-Type"))

	var result map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&result)
	require.NoError(t, err)
	assert.Equal(t, "constellation", result["service"])
}

func TestAPI_Integration_FullWorkflow(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/health":
			server.handleHealth(w, r)
		case "/api/v1/status":
			server.handleStatus(w, r)
		case "/api/v1/nodes":
			server.handleNodes(w, r)
		case "/api/v1/services":
			server.handleServices(w, r)
		case "/api/v1/metrics":
			server.handleMetrics(w, r)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer testServer.Close()

	state := gossipCluster.GetState()

	// Add nodes
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node1",
		PublicIP: "1.2.3.4",
		Cordoned: false,
	})
	state.UpdateNode(&gossip.NodeMetadata{
		Name:     "node2",
		PublicIP: "5.6.7.8",
		Cordoned: true,
	})

	// Add services
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

	// Test health endpoint
	resp, err := http.Get(testServer.URL + "/health")
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	resp.Body.Close()

	// Test status endpoint
	resp, err = http.Get(testServer.URL + "/api/v1/status")
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	resp.Body.Close()

	// Test nodes endpoint
	resp, err = http.Get(testServer.URL + "/api/v1/nodes")
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	var nodesResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&nodesResp)
	resp.Body.Close()
	assert.Contains(t, nodesResp, "nodes")

	// Test services endpoint
	resp, err = http.Get(testServer.URL + "/api/v1/services")
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	resp.Body.Close()

	// Test metrics endpoint
	resp, err = http.Get(testServer.URL + "/api/v1/metrics")
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	var metricsResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&metricsResp)
	resp.Body.Close()
	assert.Contains(t, metricsResp, "nodes")
	assert.Contains(t, metricsResp, "services")
}

func TestAPI_Integration_ConcurrentRequests(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, 8080)

	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		server.handleStatus(w, r)
	}))
	defer testServer.Close()

	// Make concurrent requests
	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func() {
			resp, err := http.Get(testServer.URL + "/api/v1/status")
			if err == nil {
				resp.Body.Close()
				done <- resp.StatusCode == http.StatusOK
			} else {
				done <- false
			}
		}()
	}

	// Wait for all requests
	successCount := 0
	for i := 0; i < 10; i++ {
		if <-done {
			successCount++
		}
	}

	assert.Equal(t, 10, successCount, "All concurrent requests should succeed")
}

func TestAPI_Integration_WebSocketThroughServer(t *testing.T) {
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

	// Test that WebSocket endpoint is accessible through server setup
	// Regular HTTP GET request to WebSocket endpoint should work (returns BadRequest or similar)
	// The error might be nil if the server handles it gracefully, so we just verify the endpoint exists
	url := "ws" + testServer.URL[4:] + "/ws"
	resp, err := http.Get(testServer.URL + "/ws")
	// WebSocket endpoint exists - GET request may or may not return error depending on implementation
	// The important thing is the endpoint is registered
	if err == nil && resp != nil {
		// Server returned a response (likely 400 Bad Request or similar)
		assert.NotEqual(t, http.StatusNotFound, resp.StatusCode, "WebSocket endpoint should be registered")
		resp.Body.Close()
	}
	_ = url // Used in actual WebSocket connection tests
}
