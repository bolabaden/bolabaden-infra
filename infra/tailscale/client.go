package tailscale

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
)

// GetTailscaleIP returns the local node's Tailscale IP
func GetTailscaleIP() (string, error) {
	cmd := exec.Command("tailscale", "ip", "-4")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get Tailscale IP: %w", err)
	}

	ip := strings.TrimSpace(string(out))
	if ip == "" {
		return "", fmt.Errorf("Tailscale IP is empty")
	}

	return ip, nil
}

// DiscoverPeers discovers peer nodes via Tailscale and returns their IPs
func DiscoverPeers() ([]string, error) {
	discovery := NewTailscaleDiscovery()
	ctx := context.Background()

	peers, err := discovery.DiscoverPeers(ctx)
	if err != nil {
		return nil, err
	}

	ips := make([]string, 0, len(peers))
	for _, peer := range peers {
		if peer.Online && peer.IP != "" {
			ips = append(ips, peer.IP)
		}
	}

	return ips, nil
}

// GetLocalHostname returns the local Tailscale hostname
func GetLocalHostname() (string, error) {
	cmd := exec.Command("tailscale", "status", "--self")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get Tailscale hostname: %w", err)
	}

	// Parse output (format: "hostname (ip)")
	parts := strings.Fields(string(out))
	if len(parts) > 0 {
		return parts[0], nil
	}

	return "", fmt.Errorf("failed to parse Tailscale hostname")
}
