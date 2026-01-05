package api

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
)

// Performance tests - these may take longer to run
func BenchmarkAPI_StatusEndpoint(b *testing.B) {
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

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		resp, err := http.Get(testServer.URL + "/api/v1/status")
		if err == nil {
			resp.Body.Close()
		}
	}
}

func BenchmarkAPI_ConcurrentStatusRequests(b *testing.B) {
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

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			resp, err := http.Get(testServer.URL + "/api/v1/status")
			if err == nil {
				resp.Body.Close()
			}
		}
	})
}

func TestPerformance_LoadTest_StatusEndpoint(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping performance test in short mode")
	}

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

	// Load test: 1000 requests
	concurrency := 50
	requestsPerWorker := 20
	var wg sync.WaitGroup
	var successCount, errorCount int64
	var mu sync.Mutex

	start := time.Now()

	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < requestsPerWorker; j++ {
				resp, err := http.Get(testServer.URL + "/api/v1/status")
				mu.Lock()
				if err == nil && resp.StatusCode == http.StatusOK {
					successCount++
					resp.Body.Close()
				} else {
					errorCount++
				}
				mu.Unlock()
			}
		}()
	}

	wg.Wait()
	duration := time.Since(start)
	totalRequests := int64(concurrency * requestsPerWorker)

	t.Logf("Load test results:")
	t.Logf("  Total requests: %d", totalRequests)
	t.Logf("  Successful: %d", successCount)
	t.Logf("  Errors: %d", errorCount)
	t.Logf("  Duration: %v", duration)
	t.Logf("  Requests/sec: %.2f", float64(totalRequests)/duration.Seconds())

	assert.Greater(t, successCount, int64(totalRequests*9/10), "At least 90% of requests should succeed")
	assert.Less(t, duration, 5*time.Second, "All requests should complete within 5 seconds")
}

func TestPerformance_ConcurrentWebSocketConnections(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping performance test in short mode")
	}

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

	// Test with multiple concurrent connections
	numConnections := 100
	var wg sync.WaitGroup
	var successCount int64
	var mu sync.Mutex

	start := time.Now()

	for i := 0; i < numConnections; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			url := "ws" + testServer.URL[4:] + "/ws"
			dialer := websocket.Dialer{}
			conn, _, err := dialer.Dial(url, nil)
			if err == nil {
				mu.Lock()
				successCount++
				mu.Unlock()
				conn.Close()
			}
		}()
	}

	wg.Wait()
	duration := time.Since(start)

	t.Logf("WebSocket connection test:")
	t.Logf("  Total connections attempted: %d", numConnections)
	t.Logf("  Successful: %d", successCount)
	t.Logf("  Duration: %v", duration)

	assert.Greater(t, successCount, int64(numConnections*8/10), "At least 80% of connections should succeed")
}

func BenchmarkWebSocket_Broadcast(b *testing.B) {
	gossipCluster := createTestGossipCluster()
	consensusManager := createTestConsensusManager()
	defer consensusManager.Shutdown()
	wsServer := NewWebSocketServer(gossipCluster, consensusManager)

	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/ws" {
			wsServer.HandleWebSocket(w, r)
		}
	}))
	defer testServer.Close()

	// Connect 10 clients
	url := "ws" + testServer.URL[4:] + "/ws"
	dialer := websocket.Dialer{}
	var conns []*websocket.Conn
	for i := 0; i < 10; i++ {
		conn, _, _ := dialer.Dial(url, nil)
		if conn != nil {
			conns = append(conns, conn)
		}
	}
	defer func() {
		for _, conn := range conns {
			if conn != nil {
				conn.Close()
			}
		}
	}()

	// Wait for connections
	time.Sleep(100 * time.Millisecond)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		wsServer.Broadcast(map[string]interface{}{
			"type": "test",
			"id":   i,
		})
	}
}
