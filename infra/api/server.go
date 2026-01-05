package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/bolabaden/my-media-stack/infra/cluster/gossip"
	"github.com/bolabaden/my-media-stack/infra/cluster/raft"
)

// Server provides REST API for cluster management
type Server struct {
	gossipCluster    *gossip.GossipCluster
	consensusManager *raft.ConsensusManager
	port             int
	server           *http.Server
}

// NewServer creates a new API server
func NewServer(gossipCluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager, port int) *Server {
	return &Server{
		gossipCluster:    gossipCluster,
		consensusManager: consensusManager,
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

	s.server = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("Starting Constellation API server on :%d", s.port)
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown() error {
	if s.server == nil {
		return nil
	}
	return s.server.Close()
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

// handleNode handles individual node requests
func (s *Server) handleNode(w http.ResponseWriter, r *http.Request) {
	// Extract node name from path
	nodeName := r.URL.Path[len("/api/v1/nodes/"):]
	if nodeName == "" {
		http.Error(w, "Node name required", http.StatusBadRequest)
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
