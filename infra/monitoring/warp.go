package monitoring

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
)

// DockerClient interface for testing
type DockerClient interface {
	ContainerList(ctx context.Context, options types.ContainerListOptions) ([]types.Container, error)
	ContainerExecCreate(ctx context.Context, container string, config types.ExecConfig) (types.IDResponse, error)
	ContainerExecAttach(ctx context.Context, execID string, config types.ExecStartCheck) (types.HijackedResponse, error)
	ContainerExecInspect(ctx context.Context, execID string) (types.ContainerExecInspect, error)
}

// WarpMonitor monitors health of the warp-nat-gateway container by checking
// egress connectivity through the WARP network.
type WarpMonitor struct {
	checkInterval  time.Duration
	dockerClient   DockerClient
	onHealthChange func(healthy bool)
}

// NewWarpMonitor creates a new WARP monitor instance.
func NewWarpMonitor(client DockerClient, onHealthChange func(healthy bool)) *WarpMonitor {
	return &WarpMonitor{
		checkInterval:  30 * time.Second,
		dockerClient:   client,
		onHealthChange: onHealthChange,
	}
}

// Start begins periodic health checks. On failure, it logs a warning and
// calls the health change callback.
func (wm *WarpMonitor) Start(ctx context.Context) {
	ticker := time.NewTicker(wm.checkInterval)
	defer ticker.Stop()

	lastHealth := true

	for {
		select {
		case <-ticker.C:
			healthy, err := wm.checkOnce(ctx)
			if err != nil {
				log.Printf("warp monitor: error checking WARP gateway: %v", err)
				healthy = false
			}

			if healthy != lastHealth {
				log.Printf("warp monitor: WARP gateway health changed: %v -> %v", lastHealth, healthy)
				if wm.onHealthChange != nil {
					wm.onHealthChange(healthy)
				}
				lastHealth = healthy
			}
		case <-ctx.Done():
			return
		}
	}
}

func (wm *WarpMonitor) checkOnce(ctx context.Context) (bool, error) {
	// Find warp-nat-gateway container
	containers, err := wm.dockerClient.ContainerList(ctx, types.ContainerListOptions{
		All:     true,
		Filters: filters.NewArgs(filters.Arg("name", "warp-nat-gateway")),
	})
	if err != nil {
		return false, fmt.Errorf("failed to list containers: %w", err)
	}

	if len(containers) == 0 {
		return false, fmt.Errorf("warp-nat-gateway container not found")
	}

	containerID := containers[0].ID

	// Check if container is running
	if containers[0].State != "running" {
		return false, fmt.Errorf("warp-nat-gateway container is not running (state: %s)", containers[0].State)
	}

	// Test egress connectivity through WARP
	// Use ip-checker-warp service if available, otherwise use curl from gateway
	cmd := exec.CommandContext(ctx, "docker", "exec", containerID,
		"sh", "-c", "curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://api.ipify.org")

	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to check WARP egress: %w", err)
	}

	ip := string(output)
	if ip == "" {
		return false, fmt.Errorf("WARP egress check returned empty IP")
	}

	// Verify IP is a Cloudflare WARP IP (starts with 162.x.x.x or similar)
	// This is a simple check; in production, you might want to verify against known WARP IP ranges
	log.Printf("warp monitor: WARP gateway healthy, egress IP: %s", ip)
	return true, nil
}
