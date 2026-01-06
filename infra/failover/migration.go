package failover

import (
	"context"
	"fmt"
	"io"
	"log"
	"sync"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"

	"cluster/infra/cluster/gossip"
	"cluster/infra/monitoring"
)

// MigrationManager handles container migration between nodes
type MigrationManager struct {
	dockerClient *client.Client
	gossipState  *gossip.ClusterState
	nodeName     string
	mu           sync.RWMutex
	migrations   map[string]*Migration // service name -> active migration
	// Remote Docker access configuration
	remoteDockerPort int  // Port for remote Docker API access (default 2375)
	remoteDockerTLS  bool // Whether to use TLS for remote Docker access
	// Metrics collection
	metricsCollector *monitoring.MetricsCollector
	lastMetrics      *monitoring.NodeMetrics
	metricsMu        sync.RWMutex
}

// Migration represents an active container migration
type Migration struct {
	ServiceName string
	SourceNode  string
	TargetNode  string
	Status      MigrationStatus
	StartedAt   time.Time
	CompletedAt *time.Time
	Error       error
}

// MigrationStatus represents the status of a migration
type MigrationStatus string

const (
	MigrationStatusPending   MigrationStatus = "pending"
	MigrationStatusRunning   MigrationStatus = "running"
	MigrationStatusCompleted MigrationStatus = "completed"
	MigrationStatusFailed    MigrationStatus = "failed"
)

// MigrationRule defines when and how to migrate containers
type MigrationRule struct {
	ServiceName string
	Trigger     MigrationTrigger
	TargetNode  string // empty = auto-select
	Priority    int    // higher = more important
	MaxRetries  int
	RetryDelay  time.Duration
}

// MigrationTrigger defines what triggers a migration
type MigrationTrigger struct {
	HealthCheckFailures int    // migrate after N consecutive failures
	ResourceThreshold   string // e.g., "cpu>80%" or "memory>90%"
	NodeUnhealthy       bool   // migrate if node becomes unhealthy
}

// NewMigrationManager creates a new migration manager
func NewMigrationManager(dockerClient *client.Client, gossipState *gossip.ClusterState, nodeName string) *MigrationManager {
	return &MigrationManager{
		dockerClient:     dockerClient,
		gossipState:      gossipState,
		nodeName:         nodeName,
		migrations:       make(map[string]*Migration),
		remoteDockerPort: 2375,  // Default Docker API port
		remoteDockerTLS:  false, // Default to no TLS (can be configured)
		metricsCollector: monitoring.NewMetricsCollector(),
	}
}

// StartMigration starts migrating a container to another node
func (mm *MigrationManager) StartMigration(ctx context.Context, rule MigrationRule) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()

	// Check if migration already in progress
	if existing, exists := mm.migrations[rule.ServiceName]; exists {
		if existing.Status == MigrationStatusRunning || existing.Status == MigrationStatusPending {
			return fmt.Errorf("migration already in progress for service %s", rule.ServiceName)
		}
	}

	// Determine target node
	targetNode := rule.TargetNode
	if targetNode == "" {
		var err error
		targetNode, err = mm.selectTargetNode(rule.ServiceName)
		if err != nil {
			return fmt.Errorf("failed to select target node: %w", err)
		}
	}

	// Create migration record
	migration := &Migration{
		ServiceName: rule.ServiceName,
		SourceNode:  mm.nodeName,
		TargetNode:  targetNode,
		Status:      MigrationStatusPending,
		StartedAt:   time.Now(),
	}

	mm.migrations[rule.ServiceName] = migration

	// Start migration in background
	go mm.executeMigration(ctx, migration, rule)

	return nil
}

// selectTargetNode selects the best target node for migration
func (mm *MigrationManager) selectTargetNode(serviceName string) (string, error) {
	state := mm.gossipState
	allNodes := state.GetAllNodes()

	// Filter to healthy, non-cordoned nodes (excluding current node)
	candidates := make([]*gossip.NodeMetadata, 0)
	for _, node := range allNodes {
		if node.Name == mm.nodeName {
			continue // Skip current node
		}
		if node.Cordoned {
			continue // Skip cordoned nodes
		}

		// Check if node already has this service
		health, exists := state.GetServiceHealth(serviceName, node.Name)
		if exists && health.Healthy {
			continue // Skip nodes that already have healthy instance
		}

		candidates = append(candidates, node)
	}

	if len(candidates) == 0 {
		return "", fmt.Errorf("no suitable target nodes available")
	}

	// Select node with lowest priority (fastest nodes first)
	bestNode := candidates[0]
	for _, node := range candidates[1:] {
		if node.Priority < bestNode.Priority {
			bestNode = node
		}
	}

	return bestNode.Name, nil
}

// executeMigration performs the actual container migration from source to target node
func (mm *MigrationManager) executeMigration(ctx context.Context, migration *Migration, rule MigrationRule) {
	mm.mu.Lock()
	migration.Status = MigrationStatusRunning
	mm.mu.Unlock()

	log.Printf("Starting migration of %s from %s to %s", migration.ServiceName, migration.SourceNode, migration.TargetNode)

	// Step 1: Validate container exists and is running on source node
	if mm.dockerClient == nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("Docker client not available")
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: Docker client not available", migration.ServiceName)
		return
	}

	// Find container on source node
	containers, err := mm.dockerClient.ContainerList(ctx, types.ContainerListOptions{
		All: true,
		Filters: filters.NewArgs(
			filters.Arg("name", migration.ServiceName),
		),
	})
	if err != nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to list containers: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	if len(containers) == 0 {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("container %s not found on source node", migration.ServiceName)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: container not found", migration.ServiceName)
		return
	}

	containerID := containers[0].ID
	log.Printf("Found container %s on source node", containerID)

	// Step 2: Inspect container to get full configuration
	containerConfig, err := ExportContainerConfig(ctx, mm.dockerClient, containerID)
	if err != nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to export container config: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	// Step 3: Get target node information from gossip state
	state := mm.gossipState
	targetNode, exists := state.GetNode(migration.TargetNode)
	if !exists {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("target node %s not found in cluster", migration.TargetNode)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: target node not found", migration.ServiceName)
		return
	}

	// Step 4: Create remote Docker client for target node
	remoteDocker, err := NewRemoteDockerClient(targetNode.TailscaleIP, mm.remoteDockerPort, mm.remoteDockerTLS)
	if err != nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to create remote Docker client: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	remoteCli, err := remoteDocker.CreateClient(ctx)
	if err != nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to connect to remote Docker daemon: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}
	defer remoteCli.Close()

	log.Printf("Connected to Docker daemon on target node %s", migration.TargetNode)

	// Step 5: Ensure image exists on target node (pull if needed)
	log.Printf("Ensuring image %s exists on target node", containerConfig.Image)
	imageReader, err := ExportContainerImage(ctx, mm.dockerClient, containerConfig.Image)
	if err != nil {
		log.Printf("Warning: Failed to export image from source, attempting to pull on target: %v", err)
		// Try to pull image on target instead
		pullResp, pullErr := remoteCli.ImagePull(ctx, containerConfig.Image, types.ImagePullOptions{})
		if pullErr != nil {
			mm.mu.Lock()
			migration.Status = MigrationStatusFailed
			migration.Error = fmt.Errorf("failed to ensure image on target: %w (pull error: %v)", err, pullErr)
			mm.mu.Unlock()
			log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
			return
		}
		io.Copy(io.Discard, pullResp)
		pullResp.Close()
	} else {
		// Transfer image to target
		defer imageReader.Close()
		if err := LoadContainerImage(ctx, remoteCli, imageReader); err != nil {
			log.Printf("Warning: Failed to load image on target, attempting pull: %v", err)
			// Fallback to pull
			pullResp, pullErr := remoteCli.ImagePull(ctx, containerConfig.Image, types.ImagePullOptions{})
			if pullErr != nil {
				mm.mu.Lock()
				migration.Status = MigrationStatusFailed
				migration.Error = fmt.Errorf("failed to transfer image: %w (pull error: %v)", err, pullErr)
				mm.mu.Unlock()
				log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
				return
			}
			io.Copy(io.Discard, pullResp)
			pullResp.Close()
		}
	}

	// Step 6: Transfer volumes (if any)
	if len(containerConfig.Mounts) > 0 {
		log.Printf("Transferring %d volume(s) to target node", len(containerConfig.Mounts))
		if err := TransferVolumes(ctx, mm.dockerClient, remoteCli, containerID, containerConfig.Mounts, targetNode.TailscaleIP); err != nil {
			log.Printf("Warning: Volume transfer failed (continuing anyway): %v", err)
			// Continue migration even if volume transfer fails (volumes may be shared or not critical)
		}
	}

	// Step 7: Create container on target node
	log.Printf("Creating container on target node %s", migration.TargetNode)
	targetContainerID, err := CreateContainerOnRemote(ctx, remoteCli, containerConfig)
	if err != nil {
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to create container on target: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	log.Printf("Container created on target node: %s", targetContainerID)

	// Step 8: Start container on target node
	log.Printf("Starting container on target node")
	if err := remoteCli.ContainerStart(ctx, targetContainerID, types.ContainerStartOptions{}); err != nil {
		// Cleanup: remove failed container
		remoteCli.ContainerRemove(ctx, targetContainerID, types.ContainerRemoveOptions{Force: true})
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("failed to start container on target: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	// Step 9: Verify container health on target node
	log.Printf("Verifying container health on target node")
	healthTimeout := 60 * time.Second
	if containerConfig.Healthcheck != nil {
		// Wait longer if healthcheck is configured
		healthTimeout = time.Duration(containerConfig.Healthcheck.Interval) * time.Duration(containerConfig.Healthcheck.Retries+1) * time.Second
		if healthTimeout < 30*time.Second {
			healthTimeout = 30 * time.Second
		}
	}

	if err := VerifyContainerHealth(ctx, remoteCli, targetContainerID, healthTimeout); err != nil {
		// Container started but health check failed - rollback
		log.Printf("Container health check failed, rolling back migration")
		remoteCli.ContainerStop(ctx, targetContainerID, container.StopOptions{})
		remoteCli.ContainerRemove(ctx, targetContainerID, types.ContainerRemoveOptions{Force: true})
		mm.mu.Lock()
		migration.Status = MigrationStatusFailed
		migration.Error = fmt.Errorf("container health check failed on target: %w", err)
		mm.mu.Unlock()
		log.Printf("Migration of %s failed: %v", migration.ServiceName, migration.Error)
		return
	}

	log.Printf("Container is healthy on target node")

	// Step 10: Update gossip state to reflect new service location
	// The service health monitoring will detect the new container automatically
	// but we can proactively update the state
	log.Printf("Migration of %s completed successfully", migration.ServiceName)

	// Step 11: Source container management
	// The source container is kept running initially for rollback capability.
	// After a grace period and verification that the target is stable, it can be stopped.
	// This allows for quick rollback if issues are detected on the target node.
	// The grace period and cleanup can be configured via migration rules or environment variables.
	gracePeriod := 5 * time.Minute // Default grace period before cleanup
	if rule.RetryDelay > 0 {
		gracePeriod = rule.RetryDelay * 10 // Use retry delay as basis for grace period
	}

	// Schedule source container cleanup after grace period
	go func() {
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), gracePeriod)
		defer cleanupCancel()

		select {
		case <-cleanupCtx.Done():
			// Grace period expired, verify target is still healthy
			targetHealth, exists := mm.gossipState.GetServiceHealth(migration.ServiceName, migration.TargetNode)
			if exists && targetHealth.Healthy {
				// Target is healthy, stop source container
				log.Printf("Grace period expired and target is healthy, stopping source container %s", containerID)
				stopTimeoutSeconds := 30
				stopTimeout := time.Duration(stopTimeoutSeconds) * time.Second
				if err := mm.dockerClient.ContainerStop(ctx, containerID, container.StopOptions{Timeout: &stopTimeoutSeconds}); err != nil {
					log.Printf("Warning: Failed to stop source container %s: %v", containerID, err)
				} else {
					log.Printf("Source container %s stopped successfully after grace period (%v)", containerID, stopTimeout)
				}
			} else {
				log.Printf("Target health check failed, keeping source container %s for rollback", containerID)
			}
		case <-ctx.Done():
			// Migration context cancelled, keep source container
			return
		}
	}()

	log.Printf("Source container %s will be stopped after grace period (%v) if target remains healthy", containerID, gracePeriod)

	mm.mu.Lock()
	migration.Status = MigrationStatusCompleted
	now := time.Now()
	migration.CompletedAt = &now
	mm.mu.Unlock()

	log.Printf("Migration of %s from %s to %s completed successfully", migration.ServiceName, migration.SourceNode, migration.TargetNode)
}

// GetMigrationStatus returns the status of a migration
func (mm *MigrationManager) GetMigrationStatus(serviceName string) (*Migration, bool) {
	mm.mu.RLock()
	defer mm.mu.RUnlock()

	migration, exists := mm.migrations[serviceName]
	if !exists {
		return nil, false
	}

	// Return a copy
	return &Migration{
		ServiceName: migration.ServiceName,
		SourceNode:  migration.SourceNode,
		TargetNode:  migration.TargetNode,
		Status:      migration.Status,
		StartedAt:   migration.StartedAt,
		CompletedAt: migration.CompletedAt,
		Error:       migration.Error,
	}, true
}

// MonitorAndMigrate monitors services and triggers migrations based on rules
func (mm *MigrationManager) MonitorAndMigrate(ctx context.Context, rules []MigrationRule) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			mm.CheckAndMigrate(ctx, rules)
		}
	}
}

// CheckAndMigrate checks services against migration rules and triggers migrations
// This is exported for testing purposes
func (mm *MigrationManager) CheckAndMigrate(ctx context.Context, rules []MigrationRule) {
	state := mm.gossipState

	for _, rule := range rules {
		// Check if service is unhealthy on this node
		health, exists := state.GetServiceHealth(rule.ServiceName, mm.nodeName)
		if !exists {
			continue
		}

		// Check trigger conditions
		shouldMigrate := false

		if rule.Trigger.HealthCheckFailures > 0 {
			// Use tracked consecutive failures from service health
			if health.ConsecutiveFailures >= rule.Trigger.HealthCheckFailures {
				shouldMigrate = true
				log.Printf("Service %s has %d consecutive failures (threshold: %d)", rule.ServiceName, health.ConsecutiveFailures, rule.Trigger.HealthCheckFailures)
			}
		}

		if rule.Trigger.ResourceThreshold != "" {
			// Collect current node metrics
			mm.metricsMu.Lock()
			metrics, err := mm.metricsCollector.CollectMetrics(ctx)
			if err != nil {
				log.Printf("Warning: Failed to collect metrics for threshold check: %v", err)
				mm.metricsMu.Unlock()
				continue
			}
			mm.lastMetrics = metrics
			mm.metricsMu.Unlock()

			// Evaluate resource threshold
			thresholdExceeded, err := monitoring.EvaluateResourceThreshold(metrics, rule.Trigger.ResourceThreshold)
			if err != nil {
				log.Printf("Warning: Failed to evaluate resource threshold %s for %s: %v", rule.Trigger.ResourceThreshold, rule.ServiceName, err)
				continue
			}

			if thresholdExceeded {
				log.Printf("Resource threshold exceeded for %s: %s (current: CPU=%.2f%%, Memory=%.2f%%)", rule.ServiceName, rule.Trigger.ResourceThreshold, metrics.CPUPercent, metrics.MemoryPercent)
				shouldMigrate = true
			}
		}

		if rule.Trigger.NodeUnhealthy {
			// Check if this node is unhealthy
			node, exists := state.GetNode(mm.nodeName)
			if exists && node.Cordoned {
				shouldMigrate = true
			}
		}

		if shouldMigrate {
			// Check if migration already in progress (only block if Running or Pending)
			mm.mu.RLock()
			existing, exists := mm.migrations[rule.ServiceName]
			inProgress := exists && (existing.Status == MigrationStatusRunning || existing.Status == MigrationStatusPending)
			mm.mu.RUnlock()

			if !inProgress {
				log.Printf("Triggering migration of %s due to rule: %+v", rule.ServiceName, rule.Trigger)
				if err := mm.StartMigration(ctx, rule); err != nil {
					log.Printf("Failed to start migration of %s: %v", rule.ServiceName, err)
				}
			}
		}
	}
}

// GetActiveMigrations returns all active migrations
func (mm *MigrationManager) GetActiveMigrations() []*Migration {
	mm.mu.RLock()
	defer mm.mu.RUnlock()

	result := make([]*Migration, 0, len(mm.migrations))
	for _, migration := range mm.migrations {
		if migration.Status == MigrationStatusRunning || migration.Status == MigrationStatusPending {
			result = append(result, &Migration{
				ServiceName: migration.ServiceName,
				SourceNode:  migration.SourceNode,
				TargetNode:  migration.TargetNode,
				Status:      migration.Status,
				StartedAt:   migration.StartedAt,
				CompletedAt: migration.CompletedAt,
				Error:       migration.Error,
			})
		}
	}

	return result
}
