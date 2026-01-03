package stateful

import (
	"context"
	"fmt"
	"log"
	"sync"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

// MongoDBOrchestrator manages MongoDB replica set orchestration
type MongoDBOrchestrator struct {
	replicaSetName string
	nodes          []MongoDBNode
	mu             sync.RWMutex
}

// MongoDBNode represents a MongoDB node in the replica set
type MongoDBNode struct {
	NodeName    string
	ContainerID string
	Host        string
	Port        int
	Priority    int    // Replica set priority (higher = more preferred for primary)
	Role        string // "primary", "secondary", "arbiter"
}

// NewMongoDBOrchestrator creates a new MongoDB orchestrator
func NewMongoDBOrchestrator(replicaSetName string) *MongoDBOrchestrator {
	return &MongoDBOrchestrator{
		replicaSetName: replicaSetName,
		nodes:          make([]MongoDBNode, 0),
	}
}

// AddNode adds a MongoDB node to the replica set
func (mo *MongoDBOrchestrator) AddNode(node MongoDBNode) {
	mo.mu.Lock()
	defer mo.mu.Unlock()

	// Check if node already exists
	for i, existing := range mo.nodes {
		if existing.NodeName == node.NodeName {
			mo.nodes[i] = node
			return
		}
	}

	mo.nodes = append(mo.nodes, node)
}

// RemoveNode removes a MongoDB node from the replica set
func (mo *MongoDBOrchestrator) RemoveNode(nodeName string) {
	mo.mu.Lock()
	defer mo.mu.Unlock()

	for i, node := range mo.nodes {
		if node.NodeName == nodeName {
			mo.nodes = append(mo.nodes[:i], mo.nodes[i+1:]...)
			return
		}
	}
}

// InitializeReplicaSet initializes the MongoDB replica set
func (mo *MongoDBOrchestrator) InitializeReplicaSet(ctx context.Context) error {
	mo.mu.RLock()
	if len(mo.nodes) < 1 {
		mo.mu.RUnlock()
		return fmt.Errorf("need at least 1 node to initialize replica set")
	}
	nodes := make([]MongoDBNode, len(mo.nodes))
	copy(nodes, mo.nodes)
	mo.mu.RUnlock()

	// Connect to first node
	primaryNode := nodes[0]
	client, err := mo.connectToNode(ctx, primaryNode)
	if err != nil {
		return fmt.Errorf("failed to connect to primary node: %w", err)
	}
	defer client.Disconnect(ctx)

	// Check if replica set is already initialized
	adminDB := client.Database("admin")
	result := adminDB.RunCommand(ctx, map[string]interface{}{
		"replSetGetStatus": 1,
	})

	if result.Err() == nil {
		log.Printf("Replica set %s already initialized", mo.replicaSetName)
		return nil
	}

	// Initialize replica set
	members := make([]map[string]interface{}, 0, len(nodes))
	for i, node := range nodes {
		member := map[string]interface{}{
			"_id":  i,
			"host": fmt.Sprintf("%s:%d", node.Host, node.Port),
		}
		if node.Priority > 0 {
			member["priority"] = node.Priority
		}
		members = append(members, member)
	}

	initCmd := map[string]interface{}{
		"replSetInitiate": map[string]interface{}{
			"_id":     mo.replicaSetName,
			"members": members,
		},
	}

	result = adminDB.RunCommand(ctx, initCmd)
	if err := result.Err(); err != nil {
		return fmt.Errorf("failed to initialize replica set: %w", err)
	}

	log.Printf("Initialized MongoDB replica set %s with %d members", mo.replicaSetName, len(nodes))
	return nil
}

// GetPrimaryNode returns the current primary node
func (mo *MongoDBOrchestrator) GetPrimaryNode(ctx context.Context) (*MongoDBNode, error) {
	mo.mu.RLock()
	nodes := make([]MongoDBNode, len(mo.nodes))
	copy(nodes, mo.nodes)
	mo.mu.RUnlock()

	// Try each node to find the primary
	for _, node := range nodes {
		client, err := mo.connectToNode(ctx, node)
		if err != nil {
			continue
		}

		// Check if this node is primary
		adminDB := client.Database("admin")
		result := adminDB.RunCommand(ctx, map[string]interface{}{
			"isMaster": 1,
		})

		var status map[string]interface{}
		if err := result.Decode(&status); err != nil {
			client.Disconnect(ctx)
			continue
		}

		if isMaster, ok := status["ismaster"].(bool); ok && isMaster {
			client.Disconnect(ctx)
			return &node, nil
		}

		client.Disconnect(ctx)
	}

	return nil, fmt.Errorf("no primary node found")
}

// UpdateReplicaSetMembers updates the replica set membership
func (mo *MongoDBOrchestrator) UpdateReplicaSetMembers(ctx context.Context) error {
	primary, err := mo.GetPrimaryNode(ctx)
	if err != nil {
		return fmt.Errorf("failed to get primary node: %w", err)
	}

	client, err := mo.connectToNode(ctx, *primary)
	if err != nil {
		return fmt.Errorf("failed to connect to primary: %w", err)
	}
	defer client.Disconnect(ctx)

	mo.mu.RLock()
	nodes := make([]MongoDBNode, len(mo.nodes))
	copy(nodes, mo.nodes)
	mo.mu.RUnlock()

	// Get current replica set config
	adminDB := client.Database("admin")
	result := adminDB.RunCommand(ctx, map[string]interface{}{
		"replSetGetConfig": 1,
	})

	var configResp map[string]interface{}
	if err := result.Decode(&configResp); err != nil {
		return fmt.Errorf("failed to get replica set config: %w", err)
	}

	config, ok := configResp["config"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid replica set config response")
	}

	// Build new members list
	members := make([]map[string]interface{}, 0, len(nodes))
	for i, node := range nodes {
		member := map[string]interface{}{
			"_id":  i,
			"host": fmt.Sprintf("%s:%d", node.Host, node.Port),
		}
		if node.Priority > 0 {
			member["priority"] = node.Priority
		}
		members = append(members, member)
	}

	// Update config version
	version := 1
	if v, ok := config["version"].(int32); ok {
		version = int(v) + 1
	}

	// Reconfigure replica set
	reconfigCmd := map[string]interface{}{
		"replSetReconfig": map[string]interface{}{
			"_id":     mo.replicaSetName,
			"version": version,
			"members": members,
		},
	}

	result = adminDB.RunCommand(ctx, reconfigCmd)
	if err := result.Err(); err != nil {
		return fmt.Errorf("failed to reconfigure replica set: %w", err)
	}

	log.Printf("Updated MongoDB replica set %s with %d members", mo.replicaSetName, len(nodes))
	return nil
}

// connectToNode connects to a MongoDB node
func (mo *MongoDBOrchestrator) connectToNode(ctx context.Context, node MongoDBNode) (*mongo.Client, error) {
	uri := fmt.Sprintf("mongodb://%s:%d", node.Host, node.Port)
	clientOptions := options.Client().ApplyURI(uri).
		SetReplicaSet(mo.replicaSetName).
		SetReadPreference(readpref.SecondaryPreferred())

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return nil, err
	}

	// Ping to verify connection
	if err := client.Ping(ctx, readpref.PrimaryPreferred()); err != nil {
		client.Disconnect(ctx)
		return nil, err
	}

	return client, nil
}

// MonitorReplicaSet monitors the replica set health
func (mo *MongoDBOrchestrator) MonitorReplicaSet(ctx context.Context) error {
	primary, err := mo.GetPrimaryNode(ctx)
	if err != nil {
		return fmt.Errorf("replica set has no primary: %w", err)
	}

	log.Printf("MongoDB replica set %s: primary is %s", mo.replicaSetName, primary.NodeName)

	// Check replica set status
	client, err := mo.connectToNode(ctx, *primary)
	if err != nil {
		return fmt.Errorf("failed to connect to primary: %w", err)
	}
	defer client.Disconnect(ctx)

	adminDB := client.Database("admin")
	result := adminDB.RunCommand(ctx, map[string]interface{}{
		"replSetGetStatus": 1,
	})

	var status map[string]interface{}
	if err := result.Decode(&status); err != nil {
		return fmt.Errorf("failed to get replica set status: %w", err)
	}

	// Log member statuses
	if members, ok := status["members"].([]interface{}); ok {
		for _, member := range members {
			if m, ok := member.(map[string]interface{}); ok {
				stateStr := "unknown"
				if state, ok := m["stateStr"].(string); ok {
					stateStr = state
				}
				health := 0.0
				if h, ok := m["health"].(float64); ok {
					health = h
				}
				log.Printf("  Member: %v, State: %s, Health: %.0f", m["name"], stateStr, health)
			}
		}
	}

	return nil
}
