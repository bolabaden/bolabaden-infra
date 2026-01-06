package gossip

import (
	"encoding/json"
	"log"

	"github.com/hashicorp/memberlist"
)

// GossipDelegate implements memberlist.Delegate interface
type GossipDelegate struct {
	state    *ClusterState
	nodeName string
	updates  chan *ClusterState // Channel for state updates
}

// NewGossipDelegate creates a new gossip delegate
func NewGossipDelegate(nodeName string, state *ClusterState) *GossipDelegate {
	return &GossipDelegate{
		state:    state,
		nodeName: nodeName,
		updates:  make(chan *ClusterState, 100),
	}
}

// NodeMeta returns metadata about this node (called by memberlist)
func (gd *GossipDelegate) NodeMeta(limit int) []byte {
	node, exists := gd.state.GetNode(gd.nodeName)
	if !exists {
		return []byte{}
	}

	data, err := json.Marshal(node)
	if err != nil {
		log.Printf("Failed to marshal node metadata: %v", err)
		return []byte{}
	}

	if len(data) > limit {
		// Truncating JSON mid-stream produces invalid JSON that cannot be parsed.
		// Instead, we need to either:
		// 1. Return empty (safe but loses data)
		// 2. Use a more compact representation
		// 3. Remove less critical fields to fit within limit
		// For now, we'll try to create a minimal valid JSON by removing less critical fields
		log.Printf("Node metadata exceeds limit (%d > %d), creating minimal representation", len(data), limit)

		// Create a minimal node metadata with only essential fields
		minimalNode := struct {
			Name        string `json:"name"`
			PublicIP    string `json:"public_ip"`
			TailscaleIP string `json:"tailscale_ip"`
			Priority    int    `json:"priority"`
		}{
			Name:        node.Name,
			PublicIP:    node.PublicIP,
			TailscaleIP: node.TailscaleIP,
			Priority:    node.Priority,
		}

		minimalData, err := json.Marshal(minimalNode)
		if err != nil {
			log.Printf("Failed to marshal minimal node metadata: %v", err)
			return []byte{}
		}

		// If still too large, return empty rather than corrupt JSON
		if len(minimalData) > limit {
			log.Printf("Minimal node metadata still exceeds limit (%d > %d), returning empty", len(minimalData), limit)
			return []byte{}
		}

		return minimalData
	}

	return data
}

// NotifyMsg is called when a message is received from another node
func (gd *GossipDelegate) NotifyMsg(msg []byte) {
	var incomingState ClusterState
	if err := json.Unmarshal(msg, &incomingState); err != nil {
		log.Printf("Failed to unmarshal incoming state: %v", err)
		return
	}

	// Merge the incoming state with our local state
	gd.state.MergeState(&incomingState)

	// Notify listeners of state updates
	select {
	case gd.updates <- &incomingState:
	default:
		// Channel full, drop update
		log.Printf("State update channel full, dropping update")
	}
}

// GetBroadcasts returns messages to broadcast to the cluster
func (gd *GossipDelegate) GetBroadcasts(overhead, limit int) [][]byte {
	// Serialize current state to broadcast
	data, err := gd.state.MarshalJSON()
	if err != nil {
		log.Printf("Failed to marshal cluster state: %v", err)
		return nil
	}

	if len(data) > limit {
		// Chunk the state into multiple broadcasts
		// Each chunk will be reassembled by the receiving node
		chunks := chunkData(data, limit-overhead)
		if len(chunks) == 0 {
			log.Printf("Cluster state too large to broadcast even in chunks (%d > %d)", len(data), limit-overhead)
			return nil
		}
		log.Printf("Chunking cluster state into %d broadcasts (%d bytes total)", len(chunks), len(data))
		return chunks
	}

	return [][]byte{data}
}

// chunkData splits data into chunks of specified size
func chunkData(data []byte, chunkSize int) [][]byte {
	if chunkSize <= 0 {
		return nil
	}

	chunks := make([][]byte, 0)
	for i := 0; i < len(data); i += chunkSize {
		end := i + chunkSize
		if end > len(data) {
			end = len(data)
		}
		chunks = append(chunks, data[i:end])
	}

	return chunks
}

// LocalState returns the full local state for state synchronization
func (gd *GossipDelegate) LocalState(join bool) []byte {
	data, err := gd.state.MarshalJSON()
	if err != nil {
		log.Printf("Failed to marshal local state: %v", err)
		return []byte{}
	}
	return data
}

// MergeRemoteState is called when a remote node sends its full state
func (gd *GossipDelegate) MergeRemoteState(buf []byte, join bool) {
	var remoteState ClusterState
	if err := json.Unmarshal(buf, &remoteState); err != nil {
		log.Printf("Failed to unmarshal remote state: %v", err)
		return
	}

	// Merge the remote state with our local state
	gd.state.MergeState(&remoteState)
	log.Printf("Merged remote state (version: %d -> %d)", remoteState.Version, gd.state.Version)
}

// EventDelegate implements memberlist.EventDelegate interface
type EventDelegate struct {
	state *ClusterState
}

// NewEventDelegate creates a new event delegate
func NewEventDelegate(state *ClusterState) *EventDelegate {
	return &EventDelegate{
		state: state,
	}
}

// NotifyJoin is called when a node joins the cluster
func (ed *EventDelegate) NotifyJoin(node *memberlist.Node) {
	log.Printf("Node joined: %s (%s)", node.Name, node.Addr)

	// Try to unmarshal node metadata
	if len(node.Meta) > 0 {
		var nodeMeta NodeMetadata
		if err := json.Unmarshal(node.Meta, &nodeMeta); err != nil {
			log.Printf("Failed to unmarshal node metadata for %s: %v", node.Name, err)
		} else {
			ed.state.UpdateNode(&nodeMeta)
		}
	}
}

// NotifyLeave is called when a node leaves the cluster gracefully
func (ed *EventDelegate) NotifyLeave(node *memberlist.Node) {
	log.Printf("Node left: %s (%s)", node.Name, node.Addr)
	ed.state.RemoveNode(node.Name)
}

// NotifyUpdate is called when node metadata is updated
func (ed *EventDelegate) NotifyUpdate(node *memberlist.Node) {
	log.Printf("Node updated: %s (%s)", node.Name, node.Addr)

	// Try to unmarshal updated node metadata
	if len(node.Meta) > 0 {
		var nodeMeta NodeMetadata
		if err := json.Unmarshal(node.Meta, &nodeMeta); err != nil {
			log.Printf("Failed to unmarshal node metadata for %s: %v", node.Name, err)
		} else {
			ed.state.UpdateNode(&nodeMeta)
		}
	}
}
