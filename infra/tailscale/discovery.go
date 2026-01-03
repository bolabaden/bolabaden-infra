package main

import (
	"context"
	"encoding/json"
	"errors"
	"os/exec"
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

// HeadscaleFallback is a placeholder for future Headscale failover logic.
func HeadscaleFallback(ctx context.Context) error {
	// TODO: implement fallback switching logic when required.
	return errors.New("headscale fallback not implemented")
}
