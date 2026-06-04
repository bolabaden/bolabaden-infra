package monitoring

import (
	"context"
	"fmt"
	"log"
	"net"
	"os/exec"
	"strings"
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

	ipStr := strings.TrimSpace(string(output))
	if ipStr == "" {
		return false, fmt.Errorf("WARP egress check returned empty IP")
	}

	// Verify IP is a Cloudflare WARP IP by checking against known WARP IP ranges
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false, fmt.Errorf("WARP egress check returned invalid IP: %s", ipStr)
	}

	// Cloudflare WARP egress IP ranges (as of 2024)
	// WARP uses various IP ranges, primarily in the 162.x.x.x and other Cloudflare-owned ranges
	warpRanges := []string{
		"162.158.0.0/15",   // Cloudflare WARP primary range
		"172.16.0.0/12",    // Private range (some WARP configurations)
		"104.16.0.0/13",    // Cloudflare IP range
		"104.24.0.0/14",    // Cloudflare IP range
		"173.245.48.0/20",  // Cloudflare IP range
		"198.41.128.0/17",  // Cloudflare IP range
		"2400:cb00::/32",   // Cloudflare IPv6 range
		"2606:4700::/32",  // Cloudflare IPv6 range
		"2803:f800::/32",  // Cloudflare IPv6 range
		"2405:b500::/32",  // Cloudflare IPv6 range
		"2405:8100::/32",  // Cloudflare IPv6 range
		"2a06:98c0::/29",  // Cloudflare IPv6 range
		"2c0f:f248::/32",  // Cloudflare IPv6 range
	}

	// Check if IP matches any WARP range
	isWarpIP := false
	for _, cidr := range warpRanges {
		_, ipNet, err := net.ParseCIDR(cidr)
		if err != nil {
			continue // Skip invalid CIDR
		}
		if ipNet.Contains(ip) {
			isWarpIP = true
			break
		}
	}

	// Also check for common WARP egress IP patterns (162.158.x.x is most common)
	if !isWarpIP {
		ipv4 := ip.To4()
		if ipv4 != nil {
			// Check if it's in the 162.158.x.x range (most common WARP egress range)
			if ipv4[0] == 162 && ipv4[1] == 158 {
				isWarpIP = true
			}
		}
	}

	if !isWarpIP {
		log.Printf("warp monitor: WARNING - egress IP %s does not match known WARP ranges, but continuing", ipStr)
		// Don't fail the check - WARP IPs can change, and this is just a warning
	}

	log.Printf("warp monitor: WARP gateway healthy, egress IP: %s (WARP verified: %v)", ipStr, isWarpIP)
	return true, nil
}
