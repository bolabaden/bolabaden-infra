package tailscale

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// TailscalePeer represents minimal peer info discovered from tailscale status.
type TailscalePeer struct {
	Hostname string
	IP       string
	Online   bool
}

// TailscaleDiscovery queries the local tailscale daemon for peers.
type TailscaleDiscovery struct {
	timeout time.Duration
}

func NewTailscaleDiscovery() *TailscaleDiscovery {
	return &TailscaleDiscovery{
		timeout: 5 * time.Second,
	}
}

// DiscoverPeers returns peers from tailscale status. It is safe to call even if
// tailscale is unavailable; it returns an empty slice and no error in that case.
func (d *TailscaleDiscovery) DiscoverPeers(ctx context.Context) ([]TailscalePeer, error) {
	status, err := d.runStatus(ctx)
	if err != nil {
		// Gracefully degrade: no peers if tailscale unavailable.
		return []TailscalePeer{}, nil
	}

	peers := []TailscalePeer{}
	peerData, ok := status["Peer"].(map[string]any)
	if !ok {
		return peers, nil
	}

	for _, v := range peerData {
		entry, ok := v.(map[string]any)
		if !ok {
			continue
		}
		peer := TailscalePeer{
			Hostname: asString(entry["HostName"]),
			IP:       firstString(entry["TailscaleIPs"]),
			Online:   asBool(entry["Online"]),
		}
		peers = append(peers, peer)
	}

	return peers, nil
}

func (d *TailscaleDiscovery) runStatus(ctx context.Context) (map[string]any, error) {
	cmdCtx, cancel := context.WithTimeout(ctx, d.timeout)
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, "tailscale", "status", "--json")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var parsed map[string]any
	if err := json.Unmarshal(out, &parsed); err != nil {
		return nil, err
	}
	return parsed, nil
}

func asString(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func asBool(v any) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return false
}

func firstString(v any) string {
	switch t := v.(type) {
	case []any:
		for _, el := range t {
			if s, ok := el.(string); ok {
				return s
			}
		}
	case []string:
		if len(t) > 0 {
			return t[0]
		}
	}
	return ""
}

// HeadscaleFallback implements fallback logic for Headscale.
// If Headscale is unavailable, it attempts to switch Tailscale to use default login servers.
func HeadscaleFallback(ctx context.Context) error {
	headscaleURL := os.Getenv("HEADSCALE_URL")
	if headscaleURL == "" {
		// Try to detect Headscale from common locations
		headscaleURL = detectHeadscaleURL()
	}

	if headscaleURL == "" {
		// No Headscale configured, use default Tailscale servers
		return switchToDefaultTailscale(ctx)
	}

	// Check if Headscale is available
	if !isHeadscaleAvailable(ctx, headscaleURL) {
		log.Printf("Headscale unavailable at %s, falling back to default Tailscale servers", headscaleURL)
		return switchToDefaultTailscale(ctx)
	}

	// Headscale is available, ensure we're using it
	return switchToHeadscale(ctx, headscaleURL)
}

// detectHeadscaleURL attempts to detect Headscale URL from environment or common locations
func detectHeadscaleURL() string {
	// Try environment variable
	if url := os.Getenv("HEADSCALE_URL"); url != "" {
		return url
	}

	// Try common Headscale hostnames
	domain := os.Getenv("DOMAIN")
	if domain != "" {
		// Try headscale.<domain>
		candidate := fmt.Sprintf("https://headscale.%s", domain)
		if isHeadscaleAvailable(context.Background(), candidate) {
			return candidate
		}
	}

	// Try localhost
	if isHeadscaleAvailable(context.Background(), "http://localhost:8080") {
		return "http://localhost:8080"
	}

	return ""
}

// isHeadscaleAvailable checks if Headscale is reachable
func isHeadscaleAvailable(ctx context.Context, url string) bool {
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url+"/health", nil)
	if err != nil {
		return false
	}

	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusNotFound
}

// switchToHeadscale configures Tailscale to use Headscale
func switchToHeadscale(ctx context.Context, headscaleURL string) error {
	// Extract hostname from URL
	hostname := extractHostname(headscaleURL)
	if hostname == "" {
		return fmt.Errorf("invalid Headscale URL: %s", headscaleURL)
	}

	// Use tailscale set to configure login server
	cmd := exec.CommandContext(ctx, "tailscale", "set", "--login-server", hostname)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set Headscale login server: %w", err)
	}

	log.Printf("Switched Tailscale to use Headscale at %s", hostname)
	return nil
}

// switchToDefaultTailscale configures Tailscale to use default login servers
func switchToDefaultTailscale(ctx context.Context) error {
	// Use tailscale set to use default login servers
	cmd := exec.CommandContext(ctx, "tailscale", "set", "--login-server", "")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to switch to default Tailscale servers: %w", err)
	}

	log.Printf("Switched Tailscale to use default login servers")
	return nil
}

// extractHostname extracts hostname from URL
func extractHostname(urlStr string) string {
	// Remove protocol prefix (http://, https://)
	if strings.HasPrefix(urlStr, "http://") {
		urlStr = strings.TrimPrefix(urlStr, "http://")
	} else if strings.HasPrefix(urlStr, "https://") {
		urlStr = strings.TrimPrefix(urlStr, "https://")
	}

	// Remove path
	if idx := strings.Index(urlStr, "/"); idx != -1 {
		urlStr = urlStr[:idx]
	}

	// Extract hostname (before port)
	host, _, err := net.SplitHostPort(urlStr)
	if err == nil {
		return host
	}

	return urlStr
}
