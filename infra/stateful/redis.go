package stateful

import (
	"context"
	"fmt"
	"log"
	"sync"

	"github.com/go-redis/redis/v8"
)

// RedisOrchestrator manages Redis Sentinel/Cluster orchestration
type RedisOrchestrator struct {
	masterName    string
	sentinels     []RedisSentinel
	redisNodes    []RedisNode
	mu            sync.RWMutex
	currentMaster *RedisNode
}

// RedisSentinel represents a Redis Sentinel instance
type RedisSentinel struct {
	NodeName    string
	Host        string
	Port        int
	ContainerID string
}

// RedisNode represents a Redis instance
type RedisNode struct {
	NodeName    string
	Host        string
	Port        int
	ContainerID string
	Role        string // "master", "slave", "sentinel"
	MasterID    string // For slaves, the master's ID
}

// NewRedisOrchestrator creates a new Redis orchestrator
func NewRedisOrchestrator(masterName string) *RedisOrchestrator {
	return &RedisOrchestrator{
		masterName: masterName,
		sentinels:  make([]RedisSentinel, 0),
		redisNodes: make([]RedisNode, 0),
	}
}

// AddSentinel adds a Sentinel instance
func (ro *RedisOrchestrator) AddSentinel(sentinel RedisSentinel) {
	ro.mu.Lock()
	defer ro.mu.Unlock()

	// Check if sentinel already exists
	for i, existing := range ro.sentinels {
		if existing.NodeName == sentinel.NodeName {
			ro.sentinels[i] = sentinel
			return
		}
	}

	ro.sentinels = append(ro.sentinels, sentinel)
}

// AddRedisNode adds a Redis node
func (ro *RedisOrchestrator) AddRedisNode(node RedisNode) {
	ro.mu.Lock()
	defer ro.mu.Unlock()

	// Check if node already exists
	for i, existing := range ro.redisNodes {
		if existing.NodeName == node.NodeName {
			ro.redisNodes[i] = node
			return
		}
	}

	ro.redisNodes = append(ro.redisNodes, node)
}

// InitializeSentinel initializes Redis Sentinel monitoring
func (ro *RedisOrchestrator) InitializeSentinel(ctx context.Context) error {
	ro.mu.RLock()
	if len(ro.sentinels) < 3 {
		ro.mu.RUnlock()
		return fmt.Errorf("need at least 3 sentinels for quorum")
	}
	if len(ro.redisNodes) < 2 {
		ro.mu.RUnlock()
		return fmt.Errorf("need at least 2 Redis nodes (1 master, 1 slave)")
	}
	sentinels := make([]RedisSentinel, len(ro.sentinels))
	copy(sentinels, ro.sentinels)
	redisNodes := make([]RedisNode, len(ro.redisNodes))
	copy(redisNodes, ro.redisNodes)
	ro.mu.RUnlock()

	// Find master node (first node or node with role=master)
	var masterNode *RedisNode
	for i := range redisNodes {
		if redisNodes[i].Role == "master" || i == 0 {
			masterNode = &redisNodes[i]
			break
		}
	}

	if masterNode == nil {
		return fmt.Errorf("no master node found")
	}

	// Configure each sentinel to monitor the master
	for _, sentinel := range sentinels {
		client := redis.NewClient(&redis.Options{
			Addr:     fmt.Sprintf("%s:%d", sentinel.Host, sentinel.Port),
			Password: "", // TODO: Get from config
		})

		// Send SENTINEL MONITOR command
		quorum := len(sentinels)/2 + 1 // Majority

		cmd := client.Do(ctx, "SENTINEL", "MONITOR", ro.masterName, masterNode.Host, masterNode.Port, quorum)
		if err := cmd.Err(); err != nil {
			client.Close()
			log.Printf("Warning: failed to configure sentinel %s: %v", sentinel.NodeName, err)
			continue
		}

		// Set down-after-milliseconds
		if err := client.Do(ctx, "SENTINEL", "SET", ro.masterName, "down-after-milliseconds", "5000").Err(); err != nil {
			log.Printf("Warning: failed to set down-after-milliseconds on sentinel %s: %v", sentinel.NodeName, err)
		}

		// Set failover-timeout
		if err := client.Do(ctx, "SENTINEL", "SET", ro.masterName, "failover-timeout", "60000").Err(); err != nil {
			log.Printf("Warning: failed to set failover-timeout on sentinel %s: %v", sentinel.NodeName, err)
		}

		client.Close()
		log.Printf("Configured sentinel %s to monitor %s", sentinel.NodeName, ro.masterName)
	}

	// Configure slaves
	for i := range redisNodes {
		if redisNodes[i].NodeName == masterNode.NodeName {
			continue // Skip master
		}

		// Configure as slave
		slaveClient := redis.NewClient(&redis.Options{
			Addr:     fmt.Sprintf("%s:%d", redisNodes[i].Host, redisNodes[i].Port),
			Password: "", // TODO: Get from config
		})

		// Send SLAVEOF command
		if err := slaveClient.SlaveOf(ctx, masterNode.Host, fmt.Sprintf("%d", masterNode.Port)).Err(); err != nil {
			log.Printf("Warning: failed to configure slave %s: %v", redisNodes[i].NodeName, err)
		} else {
			log.Printf("Configured Redis node %s as slave of %s", redisNodes[i].NodeName, masterNode.NodeName)
		}

		slaveClient.Close()
	}

	ro.mu.Lock()
	ro.currentMaster = masterNode
	ro.mu.Unlock()

	return nil
}

// GetCurrentMaster returns the current master node
func (ro *RedisOrchestrator) GetCurrentMaster(ctx context.Context) (*RedisNode, error) {
	ro.mu.RLock()
	sentinels := make([]RedisSentinel, len(ro.sentinels))
	copy(sentinels, ro.sentinels)
	ro.mu.RUnlock()

	// Query sentinels to find current master
	for _, sentinel := range sentinels {
		client := redis.NewClient(&redis.Options{
			Addr:     fmt.Sprintf("%s:%d", sentinel.Host, sentinel.Port),
			Password: "",
		})

		// Get master info
		result, err := client.Do(ctx, "SENTINEL", "GET-MASTER-ADDR-BY-NAME", ro.masterName).Result()
		if err != nil {
			client.Close()
			continue
		}

		// Parse result (array of [host, port])
		if addrs, ok := result.([]interface{}); ok && len(addrs) >= 2 {
			host := fmt.Sprintf("%v", addrs[0])
			port := 6379
			if p, ok := addrs[1].(string); ok {
				fmt.Sscanf(p, "%d", &port)
			}

			client.Close()

			// Find matching node
			ro.mu.RLock()
			for i := range ro.redisNodes {
				if ro.redisNodes[i].Host == host && ro.redisNodes[i].Port == port {
					master := ro.redisNodes[i]
					ro.mu.RUnlock()
					return &master, nil
				}
			}
			ro.mu.RUnlock()

			// Return new node if not found in our list
			return &RedisNode{
				Host: host,
				Port: port,
				Role: "master",
			}, nil
		}

		client.Close()
	}

	return nil, fmt.Errorf("no master found via sentinels")
}

// MonitorSentinel monitors Redis Sentinel health
func (ro *RedisOrchestrator) MonitorSentinel(ctx context.Context) error {
	master, err := ro.GetCurrentMaster(ctx)
	if err != nil {
		return fmt.Errorf("failed to get current master: %w", err)
	}

	ro.mu.Lock()
	ro.currentMaster = master
	ro.mu.Unlock()

	log.Printf("Redis master for %s: %s:%d", ro.masterName, master.Host, master.Port)

	// Check sentinel status
	ro.mu.RLock()
	sentinels := make([]RedisSentinel, len(ro.sentinels))
	copy(sentinels, ro.sentinels)
	ro.mu.RUnlock()

	for _, sentinel := range sentinels {
		client := redis.NewClient(&redis.Options{
			Addr:     fmt.Sprintf("%s:%d", sentinel.Host, sentinel.Port),
			Password: "",
		})

		// Get sentinel info
		info, err := client.Do(ctx, "SENTINEL", "SENTINELS", ro.masterName).Result()
		if err != nil {
			log.Printf("  Sentinel %s: error querying - %v", sentinel.NodeName, err)
		} else {
			log.Printf("  Sentinel %s: active (monitoring %d sentinels)", sentinel.NodeName, len(info.([]interface{})))
		}

		client.Close()
	}

	return nil
}

// GetMasterEndpoint returns the current master endpoint for routing
func (ro *RedisOrchestrator) GetMasterEndpoint() string {
	ro.mu.RLock()
	defer ro.mu.RUnlock()

	if ro.currentMaster != nil {
		return fmt.Sprintf("%s:%d", ro.currentMaster.Host, ro.currentMaster.Port)
	}

	return ""
}
