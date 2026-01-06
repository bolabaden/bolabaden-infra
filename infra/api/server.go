package api

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"cluster/infra/cluster/gossip"
	"cluster/infra/cluster/raft"
	"cluster/infra/failover"
)

// Server provides REST API for cluster management
type Server struct {
	gossipCluster    *gossip.GossipCluster
	consensusManager *raft.ConsensusManager
	migrationManager *failover.MigrationManager
	wsServer         *WebSocketServer
	port             int
	server           *http.Server
}

// NewServer creates a new API server
func NewServer(gossipCluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager, migrationManager *failover.MigrationManager, wsServer *WebSocketServer, port int) *Server {
	return &Server{
		gossipCluster:    gossipCluster,
		consensusManager: consensusManager,
		migrationManager: migrationManager,
		wsServer:         wsServer,
		port:             port,
	}
}

// Start starts the API server
func (s *Server) Start() error {
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", s.handleHealth)

	// Cluster status
	mux.HandleFunc("/api/v1/status", s.handleStatus)

	// Nodes
	mux.HandleFunc("/api/v1/nodes", s.handleNodes)
	mux.HandleFunc("/api/v1/nodes/", s.handleNode)

	// Services
	mux.HandleFunc("/api/v1/services", s.handleServices)
	mux.HandleFunc("/api/v1/services/", s.handleService)

	// Raft status
	mux.HandleFunc("/api/v1/raft/status", s.handleRaftStatus)
	mux.HandleFunc("/api/v1/raft/leader", s.handleRaftLeader)

	// Metrics
	mux.HandleFunc("/api/v1/metrics", s.handleMetrics)

	// Migrations
	mux.HandleFunc("/api/v1/migrations", s.handleMigrations)
	mux.HandleFunc("/api/v1/migrations/", s.handleMigration)

	// WebSocket
	if s.wsServer != nil {
		mux.HandleFunc("/ws", s.wsServer.HandleWebSocket)
	}

	s.server = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("Starting Constellation API server on :%d", s.port)
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the server with a timeout
func (s *Server) Shutdown(ctx context.Context) error {
	if s.server == nil {
		return nil
	}
	log.Printf("Shutting down API server...")
	
	// Shutdown WebSocket server first to close all connections
	if s.wsServer != nil {
		s.wsServer.Shutdown()
	}
	
	// Gracefully shutdown HTTP server with context timeout
	shutdownCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	
	if err := s.server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Error during API server shutdown: %v", err)
		// Force close if graceful shutdown fails
		return s.server.Close()
	}
	
	log.Printf("API server shutdown complete")
	return nil
}

// handleHealth handles health check requests
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// handleStatus handles cluster status requests
func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	state := s.gossipCluster.GetState()
	allNodes := state.GetAllNodes()

	nodeCount := len(allNodes)
	healthyNodeCount := 0
	for _, node := range allNodes {
		if !node.Cordoned {
			healthyNodeCount++
		}
	}

	allServices := state.GetAllServiceHealth()
	serviceCount := len(allServices)
	healthyServiceCount := 0
	for _, health := range allServices {
		if health.Healthy {
			healthyServiceCount++
		}
	}

	isLeader := s.consensusManager.IsLeader()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"service":          "constellation",
		"nodes":            nodeCount,
		"healthy_nodes":    healthyNodeCount,
		"services":         serviceCount,
		"healthy_services": healthyServiceCount,
		"raft_leader":      isLeader,
		"cluster_version":  state.Version,
		"timestamp":        time.Now().UTC().Format(time.RFC3339),
	})
}

// handleNodes handles node list requests
func (s *Server) handleNodes(w http.ResponseWriter, r *http.Request) {
	state := s.gossipCluster.GetState()
	allNodes := state.GetAllNodes()

	nodes := make([]map[string]interface{}, 0, len(allNodes))
	for _, node := range allNodes {
		// Get WARP health
		warpHealth, _ := state.GetWARPHealth(node.Name)

		nodes = append(nodes, map[string]interface{}{
			"name":         node.Name,
			"public_ip":    node.PublicIP,
			"tailscale_ip": node.TailscaleIP,
			"priority":     node.Priority,
			"capabilities": node.Capabilities,
			"last_seen":    node.LastSeen.Format(time.RFC3339),
			"cordoned":     node.Cordoned,
			"warp_healthy": warpHealth != nil && warpHealth.Healthy,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"nodes": nodes,
	})
}

// handleNode handles individual node requests and operations
func (s *Server) handleNode(w http.ResponseWriter, r *http.Request) {
	// Extract node name and operation from path
	path := r.URL.Path[len("/api/v1/nodes/"):]
	
	// Check for operations (cordon/uncordon)
	if path != "" {
		parts := splitPath(path)
		if len(parts) == 2 {
			nodeName := parts[0]
			operation := parts[1]
			
			if r.Method == http.MethodPost {
				if operation == "cordon" {
					s.handleNodeCordon(w, r, nodeName)
					return
				} else if operation == "uncordon" {
					s.handleNodeUncordon(w, r, nodeName)
					return
				}
			}
		}
	}
	
	// Extract node name from path (before any operation)
	var nodeName string
	if path != "" {
		parts := splitPath(path)
		nodeName = parts[0]
	}
	
	if nodeName == "" {
		http.Error(w, "Node name required", http.StatusBadRequest)
		return
	}

	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	state := s.gossipCluster.GetState()
	node, exists := state.GetNode(nodeName)
	if !exists {
		http.Error(w, "Node not found", http.StatusNotFound)
		return
	}

	// Get WARP health
	warpHealth, _ := state.GetWARPHealth(nodeName)

	// Get services on this node
	allServices := state.GetAllServiceHealth()
	nodeServices := make([]map[string]interface{}, 0)
	for _, health := range allServices {
		if health.NodeName == nodeName {
			nodeServices = append(nodeServices, map[string]interface{}{
				"service_name": health.ServiceName,
				"healthy":      health.Healthy,
				"checked_at":   health.CheckedAt.Format(time.RFC3339),
				"endpoints":    health.Endpoints,
				"networks":     health.Networks,
			})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"name":         node.Name,
		"public_ip":    node.PublicIP,
		"tailscale_ip": node.TailscaleIP,
		"priority":     node.Priority,
		"capabilities": node.Capabilities,
		"last_seen":    node.LastSeen.Format(time.RFC3339),
		"cordoned":     node.Cordoned,
		"warp_healthy": warpHealth != nil && warpHealth.Healthy,
		"services":     nodeServices,
	})
}

// handleNodeCordon handles node cordoning
func (s *Server) handleNodeCordon(w http.ResponseWriter, r *http.Request, nodeName string) {
	// Only allow cordoning the current node (nodes manage their own state)
	currentNodeName := s.gossipCluster.GetNodeName()
	if nodeName != currentNodeName {
		http.Error(w, fmt.Sprintf("Can only cordon the current node (%s), not %s", currentNodeName, nodeName), http.StatusForbidden)
		return
	}

	// Get current node to preserve capabilities
	state := s.gossipCluster.GetState()
	currentNode, exists := state.GetNode(nodeName)
	if !exists {
		http.Error(w, "Node not found in cluster state", http.StatusNotFound)
		return
	}

	// Get current capabilities
	capabilities := currentNode.Capabilities
	if capabilities == nil {
		capabilities = []string{}
	}

	// Update node metadata to cordoned
	s.gossipCluster.UpdateNodeMetadata(true, capabilities)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": fmt.Sprintf("Node %s cordoned", nodeName),
		"cordoned": true,
	})
}

// handleNodeUncordon handles node uncordoning
func (s *Server) handleNodeUncordon(w http.ResponseWriter, r *http.Request, nodeName string) {
	// Only allow uncordoning the current node (nodes manage their own state)
	currentNodeName := s.gossipCluster.GetNodeName()
	if nodeName != currentNodeName {
		http.Error(w, fmt.Sprintf("Can only uncordon the current node (%s), not %s", currentNodeName, nodeName), http.StatusForbidden)
		return
	}

	// Get current node to preserve capabilities
	state := s.gossipCluster.GetState()
	currentNode, exists := state.GetNode(nodeName)
	if !exists {
		http.Error(w, "Node not found in cluster state", http.StatusNotFound)
		return
	}

	// Get current capabilities
	capabilities := currentNode.Capabilities
	if capabilities == nil {
		capabilities = []string{}
	}

	// Update node metadata to uncordoned
	s.gossipCluster.UpdateNodeMetadata(false, capabilities)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": fmt.Sprintf("Node %s uncordoned", nodeName),
		"cordoned": false,
	})
}

// splitPath splits a URL path by '/' separator
func splitPath(path string) []string {
	if path == "" {
		return []string{}
	}
	parts := []string{}
	current := ""
	for _, char := range path {
		if char == '/' {
			if current != "" {
				parts = append(parts, current)
				current = ""
			}
		} else {
			current += string(char)
		}
	}
	if current != "" {
		parts = append(parts, current)
	}
	return parts
}

// handleServices handles service list requests
func (s *Server) handleServices(w http.ResponseWriter, r *http.Request) {
	state := s.gossipCluster.GetState()
	allServices := state.GetAllServiceHealth()

	// Group by service name
	serviceMap := make(map[string][]map[string]interface{})
	for _, health := range allServices {
		serviceName := health.ServiceName
		if serviceMap[serviceName] == nil {
			serviceMap[serviceName] = make([]map[string]interface{}, 0)
		}
		serviceMap[serviceName] = append(serviceMap[serviceName], map[string]interface{}{
			"node_name":  health.NodeName,
			"healthy":    health.Healthy,
			"checked_at": health.CheckedAt.Format(time.RFC3339),
			"endpoints":  health.Endpoints,
			"networks":   health.Networks,
		})
	}

	services := make([]map[string]interface{}, 0, len(serviceMap))
	for serviceName, instances := range serviceMap {
		healthyCount := 0
		for _, inst := range instances {
			if inst["healthy"].(bool) {
				healthyCount++
			}
		}

		services = append(services, map[string]interface{}{
			"service_name":  serviceName,
			"instances":     len(instances),
			"healthy_count": healthyCount,
			"nodes":         instances,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"services": services,
	})
}

// handleService handles individual service requests
func (s *Server) handleService(w http.ResponseWriter, r *http.Request) {
	// Extract service name from path
	serviceName := r.URL.Path[len("/api/v1/services/"):]
	if serviceName == "" {
		http.Error(w, "Service name required", http.StatusBadRequest)
		return
	}

	state := s.gossipCluster.GetState()
	healthyNodes := state.GetHealthyServiceNodes(serviceName)

	instances := make([]map[string]interface{}, 0)
	for _, nodeName := range healthyNodes {
		health, exists := state.GetServiceHealth(serviceName, nodeName)
		if !exists {
			continue
		}

		instances = append(instances, map[string]interface{}{
			"node_name":  health.NodeName,
			"healthy":    health.Healthy,
			"checked_at": health.CheckedAt.Format(time.RFC3339),
			"endpoints":  health.Endpoints,
			"networks":   health.Networks,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"service_name":  serviceName,
		"instances":     instances,
		"healthy_count": len(instances),
	})
}

// handleRaftStatus handles Raft status requests
func (s *Server) handleRaftStatus(w http.ResponseWriter, r *http.Request) {
	isLeader := s.consensusManager.IsLeader()
	leader := s.consensusManager.GetLeader()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"is_leader": isLeader,
		"leader":    string(leader),
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// handleRaftLeader handles Raft leader requests
func (s *Server) handleRaftLeader(w http.ResponseWriter, r *http.Request) {
	leader := s.consensusManager.GetLeader()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"leader":    string(leader),
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// handleMetrics handles metrics requests
func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
	state := s.gossipCluster.GetState()
	allNodes := state.GetAllNodes()
	allServices := state.GetAllServiceHealth()

	healthyServices := 0
	unhealthyServices := 0
	for _, health := range allServices {
		if health.Healthy {
			healthyServices++
		} else {
			unhealthyServices++
		}
	}

	healthyNodes := 0
	cordonedNodes := 0
	for _, node := range allNodes {
		if !node.Cordoned {
			healthyNodes++
		} else {
			cordonedNodes++
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"nodes": map[string]interface{}{
			"total":    len(allNodes),
			"healthy":  healthyNodes,
			"cordoned": cordonedNodes,
		},
		"services": map[string]interface{}{
			"total":     len(allServices),
			"healthy":   healthyServices,
			"unhealthy": unhealthyServices,
		},
		"raft": map[string]interface{}{
			"is_leader": s.consensusManager.IsLeader(),
			"leader":    string(s.consensusManager.GetLeader()),
		},
		"cluster_version": state.Version,
		"timestamp":       time.Now().UTC().Format(time.RFC3339),
	})
}

// handleMigrations handles migration list requests and migration creation
func (s *Server) handleMigrations(w http.ResponseWriter, r *http.Request) {
	if s.migrationManager == nil {
		http.Error(w, "Migration manager not available", http.StatusServiceUnavailable)
		return
	}

	if r.Method == http.MethodGet {
		activeMigrations := s.migrationManager.GetActiveMigrations()
		migrations := make([]map[string]interface{}, 0, len(activeMigrations))
		for _, migration := range activeMigrations {
			mig := map[string]interface{}{
				"service_name": migration.ServiceName,
				"source_node":  migration.SourceNode,
				"target_node":  migration.TargetNode,
				"status":       string(migration.Status),
				"started_at":   migration.StartedAt.Format(time.RFC3339),
			}
			if migration.CompletedAt != nil {
				mig["completed_at"] = migration.CompletedAt.Format(time.RFC3339)
			}
			migrations = append(migrations, mig)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"migrations": migrations,
		})
		return
	}

	if r.Method == http.MethodPost {
		var req struct {
			ServiceName string `json:"service_name"`
			TargetNode  string `json:"target_node,omitempty"`
			Priority    int    `json:"priority,omitempty"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
			return
		}

		if req.ServiceName == "" {
			http.Error(w, "service_name is required", http.StatusBadRequest)
			return
		}

		// Create migration rule
		rule := failover.MigrationRule{
			ServiceName: req.ServiceName,
			TargetNode:  req.TargetNode,
			Priority:    req.Priority,
			MaxRetries:  3,
			RetryDelay:  5 * time.Second,
			Trigger: failover.MigrationTrigger{
				HealthCheckFailures: 0, // Manual trigger
			},
		}

		// Start migration
		ctx := r.Context()
		if err := s.migrationManager.StartMigration(ctx, rule); err != nil {
			http.Error(w, fmt.Sprintf("Failed to start migration: %v", err), http.StatusInternalServerError)
			return
		}

		// Get migration status
		migration, exists := s.migrationManager.GetMigrationStatus(req.ServiceName)
		if !exists {
			http.Error(w, "Migration started but status not found", http.StatusInternalServerError)
			return
		}

		result := map[string]interface{}{
			"service_name": migration.ServiceName,
			"source_node":  migration.SourceNode,
			"target_node":  migration.TargetNode,
			"status":       string(migration.Status),
			"started_at":   migration.StartedAt.Format(time.RFC3339),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(result)
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}

// handleMigration handles individual migration requests
func (s *Server) handleMigration(w http.ResponseWriter, r *http.Request) {
	if s.migrationManager == nil {
		http.Error(w, "Migration manager not available", http.StatusServiceUnavailable)
		return
	}

	// Extract service name from path
	serviceName := r.URL.Path[len("/api/v1/migrations/"):]
	if serviceName == "" {
		http.Error(w, "Service name required", http.StatusBadRequest)
		return
	}

	if r.Method == http.MethodGet {
		migration, exists := s.migrationManager.GetMigrationStatus(serviceName)
		if !exists {
			http.Error(w, "Migration not found", http.StatusNotFound)
			return
		}

		result := map[string]interface{}{
			"service_name": migration.ServiceName,
			"source_node":  migration.SourceNode,
			"target_node":  migration.TargetNode,
			"status":       string(migration.Status),
			"started_at":   migration.StartedAt.Format(time.RFC3339),
		}
		if migration.CompletedAt != nil {
			result["completed_at"] = migration.CompletedAt.Format(time.RFC3339)
		}
		if migration.Error != nil {
			result["error"] = migration.Error.Error()
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(result)
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}
