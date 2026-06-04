package gossip

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/hashicorp/memberlist"
)

// GossipDelegate implements memberlist.Delegate interface
type GossipDelegate struct {
	state    *ClusterState
	nodeName string
	updates  chan *ClusterState // Channel for state updates
	chunkMu  sync.Mutex
	chunks   map[string]*stateChunkAccumulator
}

type stateChunkMessage struct {
	Kind    string `json:"kind"`
	ChunkID string `json:"chunk_id"`
	Index   int    `json:"index"`
	Total   int    `json:"total"`
	Payload []byte `json:"payload"`
}

type stateChunkAccumulator struct {
	total   int
	parts   [][]byte
	seen    int
	updated time.Time
}

// NewGossipDelegate creates a new gossip delegate
func NewGossipDelegate(nodeName string, state *ClusterState) *GossipDelegate {
	return &GossipDelegate{
		state:    state,
		nodeName: nodeName,
		updates:  make(chan *ClusterState, 100),
		chunks:   make(map[string]*stateChunkAccumulator),
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
		// We create a minimal valid JSON representation by removing less critical fields
		// to fit within the memberlist metadata size limit while preserving essential information.
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
	if err := json.Unmarshal(msg, &incomingState); err == nil {
		if incomingState.Nodes != nil || incomingState.ServiceHealth != nil || incomingState.WARPHealth != nil || incomingState.Version != 0 {
			gd.mergeIncomingState(&incomingState)
			return
		}
	} else if !gd.handleChunkMessage(msg) {
		log.Printf("Failed to unmarshal incoming state: %v", err)
		return
	}

	if !gd.handleChunkMessage(msg) {
		log.Printf("Failed to interpret incoming gossip message")
	}
}

func (gd *GossipDelegate) handleChunkMessage(msg []byte) bool {
	var chunk stateChunkMessage
	if err := json.Unmarshal(msg, &chunk); err != nil {
		return false
	}
	if chunk.Kind != "state_chunk" || chunk.Total <= 0 || chunk.Index < 0 || chunk.Index >= chunk.Total {
		return false
	}

	gd.chunkMu.Lock()
	defer gd.chunkMu.Unlock()

	now := time.Now()
	for chunkID, pending := range gd.chunks {
		if now.Sub(pending.updated) > 30*time.Second {
			delete(gd.chunks, chunkID)
		}
	}

	pending, exists := gd.chunks[chunk.ChunkID]
	if !exists {
		pending = &stateChunkAccumulator{
			total:   chunk.Total,
			parts:   make([][]byte, chunk.Total),
			updated: now,
		}
		gd.chunks[chunk.ChunkID] = pending
	}

	if pending.total != chunk.Total {
		delete(gd.chunks, chunk.ChunkID)
		return false
	}

	if pending.parts[chunk.Index] == nil {
		pending.seen++
	}
	pending.parts[chunk.Index] = append([]byte(nil), chunk.Payload...)
	pending.updated = now

	if pending.seen != pending.total {
		return true
	}

	delete(gd.chunks, chunk.ChunkID)

	fullState := make([]byte, 0)
	for _, part := range pending.parts {
		fullState = append(fullState, part...)
	}

	var incomingState ClusterState
	if err := json.Unmarshal(fullState, &incomingState); err != nil {
		log.Printf("Failed to unmarshal reassembled state chunk %s: %v", chunk.ChunkID, err)
		return true
	}

	gd.mergeIncomingState(&incomingState)
	return true
}

func (gd *GossipDelegate) mergeIncomingState(incomingState *ClusterState) {
	// Merge the incoming state with our local state
	gd.state.MergeState(incomingState)

	// Notify listeners of state updates
	select {
	case gd.updates <- incomingState:
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
		chunks := chunkData(data, limit-overhead)
		if len(chunks) == 0 {
			log.Printf("Cluster state too large to broadcast even in chunks (%d > %d)", len(data), limit-overhead)
			return nil
		}
		log.Printf("Chunking cluster state into %d broadcasts (%d bytes total)", len(chunks), len(data))

		chunkID := gd.nextChunkID()
		messages := make([][]byte, 0, len(chunks))
		for i, chunk := range chunks {
			envelope, err := json.Marshal(stateChunkMessage{
				Kind:    "state_chunk",
				ChunkID: chunkID,
				Index:   i,
				Total:   len(chunks),
				Payload: chunk,
			})
			if err != nil {
				log.Printf("Failed to marshal chunk %d/%d: %v", i+1, len(chunks), err)
				return nil
			}
			messages = append(messages, envelope)
		}

		return messages
	}

	return [][]byte{data}
}

func (gd *GossipDelegate) nextChunkID() string {
	return gd.nodeName + "-" + time.Now().UTC().Format("20060102150405.000000000")
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
