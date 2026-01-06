package gossip

import (
	"fmt"
	"log"
	"time"

	"github.com/hashicorp/memberlist"
)

// GossipCluster manages the gossip-based cluster membership
type GossipCluster struct {
	config        *Config
	memberlist    *memberlist.Memberlist
	delegate      *GossipDelegate
	eventDelegate *EventDelegate
	state         *ClusterState
}

// Config holds configuration for the gossip cluster
type Config struct {
	NodeName     string   // Name of this node
	BindAddr     string   // Address to bind to (Tailscale IP)
	BindPort     int      // Port to bind to
	PublicIP     string   // Public IP address
	TailscaleIP  string   // Tailscale IP address
	Priority     int      // Node priority (lower = higher priority)
	Capabilities []string // Node capabilities
	SeedNodes    []string // Initial seed nodes to join (Tailscale IPs or hostnames)
}

// NewGossipCluster creates a new gossip cluster
func NewGossipCluster(config *Config) (*GossipCluster, error) {
	// Create cluster state
	state := NewClusterState()

	// Initialize this node's metadata
	thisNode := &NodeMetadata{
		Name:         config.NodeName,
		PublicIP:     config.PublicIP,
		TailscaleIP:  config.TailscaleIP,
		Priority:     config.Priority,
		Capabilities: config.Capabilities,
		LastSeen:     time.Now(),
		Cordoned:     false,
	}
	state.UpdateNode(thisNode)

	// Create delegates
	gossipDelegate := NewGossipDelegate(config.NodeName, state)
	eventDelegate := NewEventDelegate(state)

	// Create memberlist config
	mlConfig := memberlist.DefaultLANConfig()
	mlConfig.Name = config.NodeName
	mlConfig.BindAddr = config.BindAddr
	mlConfig.BindPort = config.BindPort
	mlConfig.AdvertiseAddr = config.TailscaleIP // Advertise Tailscale IP
	mlConfig.Delegate = gossipDelegate
	mlConfig.Events = eventDelegate

	// Tune for Tailscale network
	mlConfig.TCPTimeout = 10 * time.Second
	mlConfig.IndirectChecks = 3
	mlConfig.RetransmitMult = 4
	mlConfig.SuspicionMult = 4
	mlConfig.ProbeInterval = 1 * time.Second
	mlConfig.ProbeTimeout = 500 * time.Millisecond
	mlConfig.GossipInterval = 200 * time.Millisecond
	mlConfig.GossipNodes = 3

	// Create memberlist
	ml, err := memberlist.Create(mlConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create memberlist: %w", err)
	}

	cluster := &GossipCluster{
		config:        config,
		memberlist:    ml,
		delegate:      gossipDelegate,
		eventDelegate: eventDelegate,
		state:         state,
	}

	// Join seed nodes if provided
	if len(config.SeedNodes) > 0 {
		if err := cluster.Join(config.SeedNodes); err != nil {
			log.Printf("Warning: failed to join seed nodes: %v", err)
			// Don't fail if we can't join seed nodes - we might be the first node
		}
	}

	return cluster, nil
}

// Join joins the cluster by contacting seed nodes
func (gc *GossipCluster) Join(seeds []string) error {
	if len(seeds) == 0 {
		return fmt.Errorf("no seed nodes provided")
	}

	log.Printf("Joining cluster with seed nodes: %v", seeds)
	n, err := gc.memberlist.Join(seeds)
	if err != nil {
		return fmt.Errorf("failed to join cluster: %w", err)
	}

	log.Printf("Successfully joined cluster, contacted %d nodes", n)
	return nil
}

// Leave gracefully leaves the cluster
func (gc *GossipCluster) Leave() error {
	timeout := 5 * time.Second
	if err := gc.memberlist.Leave(timeout); err != nil {
		return fmt.Errorf("failed to leave cluster: %w", err)
	}
	return nil
}

// Shutdown shuts down the memberlist
func (gc *GossipCluster) Shutdown() error {
	if err := gc.memberlist.Shutdown(); err != nil {
		return fmt.Errorf("failed to shutdown memberlist: %w", err)
	}
	return nil
}

// GetState returns the current cluster state
func (gc *GossipCluster) GetState() *ClusterState {
	return gc.state
}

// GetNodeName returns the name of this node
func (gc *GossipCluster) GetNodeName() string {
	return gc.config.NodeName
}

// GetMembers returns all members in the cluster
func (gc *GossipCluster) GetMembers() []*memberlist.Node {
	return gc.memberlist.Members()
}

// GetHealthyNodes returns all healthy members in the cluster
func (gc *GossipCluster) GetHealthyNodes() []*memberlist.Node {
	allMembers := gc.memberlist.Members()
	healthy := make([]*memberlist.Node, 0, len(allMembers))

	for _, member := range allMembers {
		// Check if node is in suspicion or dead state
		// memberlist doesn't expose this directly, so we check if the node is in our state
		if _, exists := gc.state.GetNode(member.Name); exists {
			healthy = append(healthy, member)
		}
	}

	return healthy
}

// BroadcastServiceHealth broadcasts service health to the cluster
func (gc *GossipCluster) BroadcastServiceHealth(serviceName string, healthy bool, endpoints map[string]string, networks []string) {
	health := &ServiceHealth{
		ServiceName: serviceName,
		NodeName:    gc.config.NodeName,
		Healthy:     healthy,
		CheckedAt:   time.Now(),
		Endpoints:   endpoints,
		Networks:    networks,
	}

	gc.state.UpdateServiceHealth(health)
	log.Printf("Broadcasted service health: %s on %s (healthy: %v)", serviceName, gc.config.NodeName, healthy)
}

// BroadcastWARPHealth broadcasts WARP gateway health to the cluster
func (gc *GossipCluster) BroadcastWARPHealth(healthy bool) {
	health := &WARPHealth{
		NodeName:  gc.config.NodeName,
		Healthy:   healthy,
		CheckedAt: time.Now(),
	}

	gc.state.UpdateWARPHealth(health)
	log.Printf("Broadcasted WARP health on %s (healthy: %v)", gc.config.NodeName, healthy)
}

// UpdateNodeMetadata updates this node's metadata
func (gc *GossipCluster) UpdateNodeMetadata(cordoned bool, capabilities []string) {
	// GetNode returns a pointer but releases the lock, so we need to create a copy
	// to avoid data races when modifying the node
	node, exists := gc.state.GetNode(gc.config.NodeName)
	if !exists {
		log.Printf("Warning: node %s not found in state", gc.config.NodeName)
		return
	}

	// Create a copy of the node to avoid data race
	// We can't modify the node directly because GetNode releases the lock
	updatedNode := &NodeMetadata{
		Name:         node.Name,
		PublicIP:     node.PublicIP,
		TailscaleIP:  node.TailscaleIP,
		Priority:     node.Priority,
		Capabilities: node.Capabilities,
		LastSeen:     time.Now(),
		Cordoned:     cordoned,
	}

	if capabilities != nil {
		// Copy capabilities slice to avoid sharing the underlying array
		updatedNode.Capabilities = make([]string, len(capabilities))
		copy(updatedNode.Capabilities, capabilities)
	}

	gc.state.UpdateNode(updatedNode)
	log.Printf("Updated node metadata for %s (cordoned: %v)", gc.config.NodeName, cordoned)
}

// GetServiceEndpoints returns endpoints for a service across the cluster
func (gc *GossipCluster) GetServiceEndpoints(serviceName string) []string {
	healthyNodes := gc.state.GetHealthyServiceNodes(serviceName)
	endpoints := make([]string, 0, len(healthyNodes))

	for _, nodeName := range healthyNodes {
		health, exists := gc.state.GetServiceHealth(serviceName, nodeName)
		if exists && health.Healthy {
			// Return HTTP endpoint if available
			if ep, ok := health.Endpoints["http"]; ok {
				endpoints = append(endpoints, ep)
			}
		}
	}

	return endpoints
}
