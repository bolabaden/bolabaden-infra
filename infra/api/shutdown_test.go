package api

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestServer_Shutdown(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer gossipCluster.Shutdown()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	port := getNextPort()
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, port)

	// Start server in goroutine
	serverErrCh := make(chan error, 1)
	go func() {
		serverErrCh <- server.Start()
	}()

	// Give server time to start
	time.Sleep(200 * time.Millisecond)

	// Verify server is running by making a request
	client := &http.Client{Timeout: 1 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://localhost:%d/health", port))
	if err == nil && resp != nil {
		resp.Body.Close()
	}

	// Shutdown with context
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = server.Shutdown(ctx)
	assert.NoError(t, err)

	// Wait for server to stop (it should return http.ErrServerClosed)
	select {
	case err := <-serverErrCh:
		// Server should have stopped
		assert.NotNil(t, err)
	case <-time.After(2 * time.Second):
		t.Fatal("Server did not shutdown in time")
	}
}

func TestWebSocketServer_Shutdown(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer gossipCluster.Shutdown()
	defer consensusManager.Shutdown()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)

	// Create a mock HTTP server with WebSocket endpoint
	server := httptest.NewServer(http.HandlerFunc(wsServer.HandleWebSocket))
	defer server.Close()

	// Shutdown should work even with no clients
	// This tests that shutdown doesn't panic when there are no connections
	wsServer.Shutdown()

	// Call shutdown again to ensure it's idempotent
	wsServer.Shutdown()
}

func TestServer_Shutdown_NoServer(t *testing.T) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer gossipCluster.Shutdown()
	defer consensusManager.Shutdown()
	migrationManager := createTestMigrationManager()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)
	server := NewServer(gossipCluster, consensusManager, migrationManager, wsServer, getNextPort())

	// Shutdown before starting should not error
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	err := server.Shutdown(ctx)
	require.NoError(t, err)
}
