package gossip

import (
	"encoding/json"
	"sync"
	"time"
)

// NodeMetadata represents metadata about a cluster node
type NodeMetadata struct {
	Name         string    `json:"name"`
	PublicIP     string    `json:"public_ip"`
	TailscaleIP  string    `json:"tailscale_ip"`
	Priority     int       `json:"priority"` // Lower = higher priority
	Capabilities []string  `json:"capabilities"`
	LastSeen     time.Time `json:"last_seen"`
	Cordoned     bool      `json:"cordoned"` // If true, don't route new traffic here
}

// ServiceHealth represents health status of a service
type ServiceHealth struct {
	ServiceName string            `json:"service_name"`
	NodeName    string            `json:"node_name"`
	Healthy     bool              `json:"healthy"`
	CheckedAt   time.Time         `json:"checked_at"`
	Endpoints   map[string]string `json:"endpoints"` // protocol -> endpoint (e.g., "http" -> "http://service:8080")
	Networks    []string          `json:"networks"`  // Which Docker networks this service is on
}

// WARPHealth represents the health status of the WARP gateway
type WARPHealth struct {
	NodeName  string    `json:"node_name"`
	Healthy   bool      `json:"healthy"`
	CheckedAt time.Time `json:"checked_at"`
}

// ClusterState holds the entire cluster state
type ClusterState struct {
	mu            sync.RWMutex
	Nodes         map[string]*NodeMetadata  // node name -> metadata
	ServiceHealth map[string]*ServiceHealth // "service@node" -> health
	WARPHealth    map[string]*WARPHealth    // node name -> WARP health
	Version       uint64                    // Monotonic version for change detection
}

// NewClusterState creates a new cluster state
func NewClusterState() *ClusterState {
	return &ClusterState{
		Nodes:         make(map[string]*NodeMetadata),
		ServiceHealth: make(map[string]*ServiceHealth),
		WARPHealth:    make(map[string]*WARPHealth),
		Version:       0,
	}
}

// UpdateNode updates or adds a node to the cluster state
func (cs *ClusterState) UpdateNode(node *NodeMetadata) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	node.LastSeen = time.Now()
	cs.Nodes[node.Name] = node
	cs.Version++
}

// GetNode retrieves a node's metadata
func (cs *ClusterState) GetNode(name string) (*NodeMetadata, bool) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	node, exists := cs.Nodes[name]
	return node, exists
}

// RemoveNode removes a node from the cluster state
func (cs *ClusterState) RemoveNode(name string) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	delete(cs.Nodes, name)
	cs.Version++

	// Remove all service health entries for this node
	for key, health := range cs.ServiceHealth {
		if health.NodeName == name {
			delete(cs.ServiceHealth, key)
		}
	}

	// Remove WARP health for this node
	delete(cs.WARPHealth, name)
}

// UpdateServiceHealth updates the health status of a service on a node
func (cs *ClusterState) UpdateServiceHealth(health *ServiceHealth) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	key := health.ServiceName + "@" + health.NodeName
	health.CheckedAt = time.Now()
	cs.ServiceHealth[key] = health
	cs.Version++
}

// GetServiceHealth retrieves the health status of a service on a node
func (cs *ClusterState) GetServiceHealth(serviceName, nodeName string) (*ServiceHealth, bool) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	key := serviceName + "@" + nodeName
	health, exists := cs.ServiceHealth[key]
	return health, exists
}

// GetHealthyServiceNodes returns all nodes where a service is healthy
func (cs *ClusterState) GetHealthyServiceNodes(serviceName string) []string {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	var healthyNodes []string
	for key, health := range cs.ServiceHealth {
		if health.ServiceName == serviceName && health.Healthy {
			healthyNodes = append(healthyNodes, health.NodeName)
		}
	}
	return healthyNodes
}

// UpdateWARPHealth updates the WARP gateway health for a node
func (cs *ClusterState) UpdateWARPHealth(health *WARPHealth) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	health.CheckedAt = time.Now()
	cs.WARPHealth[health.NodeName] = health
	cs.Version++
}

// GetWARPHealth retrieves the WARP health for a node
func (cs *ClusterState) GetWARPHealth(nodeName string) (*WARPHealth, bool) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	health, exists := cs.WARPHealth[nodeName]
	return health, exists
}

// GetAllNodes returns all nodes in the cluster
func (cs *ClusterState) GetAllNodes() []*NodeMetadata {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	nodes := make([]*NodeMetadata, 0, len(cs.Nodes))
	for _, node := range cs.Nodes {
		nodes = append(nodes, node)
	}
	return nodes
}

// MarshalJSON serializes the cluster state to JSON
func (cs *ClusterState) MarshalJSON() ([]byte, error) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	return json.Marshal(map[string]interface{}{
		"nodes":          cs.Nodes,
		"service_health": cs.ServiceHealth,
		"warp_health":    cs.WARPHealth,
		"version":        cs.Version,
	})
}

// UnmarshalJSON deserializes the cluster state from JSON
func (cs *ClusterState) UnmarshalJSON(data []byte) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	var temp struct {
		Nodes         map[string]*NodeMetadata  `json:"nodes"`
		ServiceHealth map[string]*ServiceHealth `json:"service_health"`
		WARPHealth    map[string]*WARPHealth    `json:"warp_health"`
		Version       uint64                    `json:"version"`
	}

	if err := json.Unmarshal(data, &temp); err != nil {
		return err
	}

	cs.Nodes = temp.Nodes
	cs.ServiceHealth = temp.ServiceHealth
	cs.WARPHealth = temp.WARPHealth
	cs.Version = temp.Version

	return nil
}

// MergeState merges incoming state with local state, keeping the most recent data
func (cs *ClusterState) MergeState(incoming *ClusterState) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	// Merge nodes
	for name, incomingNode := range incoming.Nodes {
		localNode, exists := cs.Nodes[name]
		if !exists || incomingNode.LastSeen.After(localNode.LastSeen) {
			cs.Nodes[name] = incomingNode
		}
	}

	// Merge service health
	for key, incomingHealth := range incoming.ServiceHealth {
		localHealth, exists := cs.ServiceHealth[key]
		if !exists || incomingHealth.CheckedAt.After(localHealth.CheckedAt) {
			cs.ServiceHealth[key] = incomingHealth
		}
	}

	// Merge WARP health
	for nodeName, incomingWARP := range incoming.WARPHealth {
		localWARP, exists := cs.WARPHealth[nodeName]
		if !exists || incomingWARP.CheckedAt.After(localWARP.CheckedAt) {
			cs.WARPHealth[nodeName] = incomingWARP
		}
	}

	cs.Version++
}
