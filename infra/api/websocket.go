package api

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/bolabaden/my-media-stack/infra/cluster/raft"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins for now - in production, restrict this
		return true
	},
}

// WebSocketServer provides real-time updates via WebSocket
type WebSocketServer struct {
	gossipCluster    *gossip.GossipCluster
	consensusManager *raft.ConsensusManager
	clients          map[*websocket.Conn]bool
	mu               sync.RWMutex
	broadcast        chan []byte
}

// NewWebSocketServer creates a new WebSocket server
func NewWebSocketServer(gossipCluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager) *WebSocketServer {
	return &WebSocketServer{
		gossipCluster:    gossipCluster,
		consensusManager: consensusManager,
		clients:          make(map[*websocket.Conn]bool),
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
	ws.mu.Unlock()

	log.Printf("WebSocket client connected: %s", r.RemoteAddr)

	// Send initial state
	ws.sendInitialState(conn)

	// Start sending periodic updates
	go ws.sendPeriodicUpdates(conn)

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
			conn.WriteMessage(websocket.TextMessage, []byte("pong"))
		}
	}

	// Unregister client
	ws.mu.Lock()
	delete(ws.clients, conn)
	ws.mu.Unlock()

	log.Printf("WebSocket client disconnected: %s", r.RemoteAddr)
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

	conn.WriteMessage(websocket.TextMessage, data)
}

// sendPeriodicUpdates sends periodic cluster state updates
func (ws *WebSocketServer) sendPeriodicUpdates(conn *websocket.Conn) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
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

			if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
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

	ws.mu.RLock()
	defer ws.mu.RUnlock()

	for client := range ws.clients {
		if err := client.WriteMessage(websocket.TextMessage, data); err != nil {
			log.Printf("Failed to send to client: %v", err)
			delete(ws.clients, client)
			client.Close()
		}
	}
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
