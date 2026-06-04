package api

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"cluster/infra/cluster/gossip"
	"cluster/infra/cluster/raft"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			// No origin header (e.g., non-browser client), allow
			return true
		}

		// Get allowed origins from environment or use default
		allowedOrigins := os.Getenv("WEBSOCKET_ALLOWED_ORIGINS")
		if allowedOrigins == "" {
			// Default: allow same-origin and localhost
			host := r.Host
			if strings.HasPrefix(origin, "http://"+host) || strings.HasPrefix(origin, "https://"+host) {
				return true
			}
			if strings.Contains(origin, "localhost") || strings.Contains(origin, "127.0.0.1") {
				return true
			}
			// Deny by default for security
			return false
		}

		// Check against allowed origins list
		allowedList := strings.Split(allowedOrigins, ",")
		for _, allowed := range allowedList {
			allowed = strings.TrimSpace(allowed)
			if origin == allowed || strings.HasPrefix(origin, allowed) {
				return true
			}
		}

		return false
	},
}

// WebSocketServer provides real-time updates via WebSocket
type WebSocketServer struct {
	gossipCluster    *gossip.GossipCluster
	consensusManager *raft.ConsensusManager
	clients          map[*websocket.Conn]bool
	mu               sync.RWMutex
	clientMu         map[*websocket.Conn]*sync.Mutex // Per-connection mutex for serializing writes
	broadcast        chan []byte
}

// NewWebSocketServer creates a new WebSocket server
func NewWebSocketServer(gossipCluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager) *WebSocketServer {
	return &WebSocketServer{
		gossipCluster:    gossipCluster,
		consensusManager: consensusManager,
		clients:          make(map[*websocket.Conn]bool),
		clientMu:         make(map[*websocket.Conn]*sync.Mutex),
		broadcast:        make(chan []byte, 256),
	}
}

// HandleWebSocket handles WebSocket connections
func (ws *WebSocketServer) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}
	defer conn.Close()

	// Register client
	ws.mu.Lock()
	ws.clients[conn] = true
	ws.clientMu[conn] = &sync.Mutex{}
	ws.mu.Unlock()

	log.Printf("WebSocket client connected: %s", r.RemoteAddr)

	// Send initial state
	ws.sendInitialState(conn)

	// Create context for periodic updates that will be cancelled when connection closes
	ctx, cancel := context.WithCancel(context.Background())

	// Start sending periodic updates
	go ws.sendPeriodicUpdates(ctx, conn)

	// Handle incoming messages (for ping/pong)
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Handle ping
		if string(message) == "ping" {
			ws.writeMessage(conn, websocket.TextMessage, []byte("pong"))
		}
	}

	// Cancel periodic updates context
	cancel()

	// Unregister client
	ws.mu.Lock()
	delete(ws.clients, conn)
	delete(ws.clientMu, conn)
	ws.mu.Unlock()

	log.Printf("WebSocket client disconnected: %s", r.RemoteAddr)
}

// Shutdown gracefully closes all WebSocket connections
func (ws *WebSocketServer) Shutdown() {
	log.Printf("Shutting down WebSocket server...")

	// Collect all connections first while holding the lock
	ws.mu.Lock()
	conns := make([]*websocket.Conn, 0, len(ws.clients))
	for conn := range ws.clients {
		conns = append(conns, conn)
	}
	clientCount := len(ws.clients)
	// Clear client maps immediately to prevent new messages
	ws.clients = make(map[*websocket.Conn]bool)
	ws.clientMu = make(map[*websocket.Conn]*sync.Mutex)
	ws.mu.Unlock()

	// Close all connections outside the lock
	for _, conn := range conns {
		// Try to send close frame, but don't fail if connection is already closed
		closeMsg := websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Server shutting down")
		// Write directly since we've already removed from clients map
		_ = conn.WriteMessage(websocket.CloseMessage, closeMsg)
		conn.Close()
	}

	log.Printf("WebSocket server shutdown complete (%d connections closed)", clientCount)
}

// sendInitialState sends the current cluster state to a new client
func (ws *WebSocketServer) sendInitialState(conn *websocket.Conn) {
	state := ws.gossipCluster.GetState()
	allNodes := state.GetAllNodes()
	allServices := state.GetAllServiceHealth()

	update := map[string]interface{}{
		"type":     "initial_state",
		"nodes":    allNodes,
		"services": allServices,
		"raft": map[string]interface{}{
			"is_leader": ws.consensusManager.IsLeader(),
			"leader":    string(ws.consensusManager.GetLeader()),
		},
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}

	data, err := json.Marshal(update)
	if err != nil {
		log.Printf("Failed to marshal initial state: %v", err)
		return
	}

	ws.writeMessage(conn, websocket.TextMessage, data)
}

// sendPeriodicUpdates sends periodic cluster state updates
func (ws *WebSocketServer) sendPeriodicUpdates(ctx context.Context, conn *websocket.Conn) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	// Also check context more frequently to respond quickly to cancellation
	checkTicker := time.NewTicker(100 * time.Millisecond)
	defer checkTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			return // Context cancelled (connection closed)
		case <-checkTicker.C:
			// Quick check if connection is still registered
			ws.mu.RLock()
			_, exists := ws.clients[conn]
			ws.mu.RUnlock()
			if !exists {
				return // Connection no longer registered
			}
		case <-ticker.C:
			// Check if connection is still registered before sending
			ws.mu.RLock()
			_, exists := ws.clients[conn]
			ws.mu.RUnlock()
			if !exists {
				return // Connection no longer registered
			}

			// Also check context before sending
			select {
			case <-ctx.Done():
				return
			default:
			}

			state := ws.gossipCluster.GetState()

			update := map[string]interface{}{
				"type":      "update",
				"version":   state.Version,
				"timestamp": time.Now().UTC().Format(time.RFC3339),
			}

			data, err := json.Marshal(update)
			if err != nil {
				log.Printf("Failed to marshal update: %v", err)
				continue
			}

			if err := ws.writeMessage(conn, websocket.TextMessage, data); err != nil {
				return // Client disconnected
			}
		}
	}
}

// Broadcast broadcasts a message to all connected clients
func (ws *WebSocketServer) Broadcast(message map[string]interface{}) {
	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Failed to marshal broadcast message: %v", err)
		return
	}

	// Collect clients to remove (to avoid modifying map while holding read lock)
	var clientsToRemove []*websocket.Conn

	// First pass: send messages and collect failed clients
	ws.mu.RLock()
	for client := range ws.clients {
		if err := ws.writeMessage(client, websocket.TextMessage, data); err != nil {
			log.Printf("Failed to send to client: %v", err)
			clientsToRemove = append(clientsToRemove, client)
		}
	}
	ws.mu.RUnlock()

	// Second pass: remove failed clients with write lock
	if len(clientsToRemove) > 0 {
		ws.mu.Lock()
		for _, client := range clientsToRemove {
			delete(ws.clients, client)
			delete(ws.clientMu, client)
			client.Close()
		}
		ws.mu.Unlock()
	}
}

// writeMessage writes a message to a WebSocket connection with proper synchronization
// Gorilla WebSocket requires that writes to a connection are serialized
func (ws *WebSocketServer) writeMessage(conn *websocket.Conn, messageType int, data []byte) error {
	ws.mu.RLock()
	mu, exists := ws.clientMu[conn]
	ws.mu.RUnlock()

	if !exists {
		// Connection not registered, write without mutex (shouldn't happen in normal flow)
		return conn.WriteMessage(messageType, data)
	}

	mu.Lock()
	defer mu.Unlock()
	return conn.WriteMessage(messageType, data)
}

// BroadcastNodeJoin broadcasts a node join event
func (ws *WebSocketServer) BroadcastNodeJoin(nodeName string) {
	ws.Broadcast(map[string]interface{}{
		"type":      "node_join",
		"node_name": nodeName,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// BroadcastNodeLeave broadcasts a node leave event
func (ws *WebSocketServer) BroadcastNodeLeave(nodeName string) {
	ws.Broadcast(map[string]interface{}{
		"type":      "node_leave",
		"node_name": nodeName,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// BroadcastServiceHealthChange broadcasts a service health change
func (ws *WebSocketServer) BroadcastServiceHealthChange(serviceName, nodeName string, healthy bool) {
	ws.Broadcast(map[string]interface{}{
		"type":         "service_health_change",
		"service_name": serviceName,
		"node_name":    nodeName,
		"healthy":      healthy,
		"timestamp":    time.Now().UTC().Format(time.RFC3339),
	})
}

// BroadcastLeaderChange broadcasts a Raft leader change
func (ws *WebSocketServer) BroadcastLeaderChange(leader string) {
	ws.Broadcast(map[string]interface{}{
		"type":      "leader_change",
		"leader":    leader,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}
