package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

// TailscaleNode represents a node discovered via Tailscale
type TailscaleNode struct {
	Name        string
	TailscaleIP string
	Priority    int // Lower = higher priority (fast nodes first)
}

// DiscoverNodes discovers all nodes via Tailscale status
func DiscoverNodes() ([]TailscaleNode, error) {
	cmd := exec.Command("tailscale", "status", "--json")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get tailscale status: %w", err)
	}

	var status TailscaleStatus
	if err := json.Unmarshal(output, &status); err != nil {
		return nil, fmt.Errorf("failed to parse tailscale status: %w", err)
	}

	nodes := []TailscaleNode{}
	nodeMap := make(map[string]string)

	// Get self (current node)
	if status.Self != nil {
		name := extractShortName(status.Self.DNSName, status.Self.HostName)
		if name != "" && len(status.Self.TailscaleIPs) > 0 {
			nodeMap[name] = status.Self.TailscaleIPs[0]
		}
	}

	// Get peers
	if status.Peer != nil {
		if peerMap, ok := status.Peer.(map[string]interface{}); ok {
			for _, peerData := range peerMap {
				peer := parsePeer(peerData)
				if peer.Name != "" && peer.IP != "" {
					nodeMap[peer.Name] = peer.IP
				}
			}
		} else if peerList, ok := status.Peer.([]interface{}); ok {
			for _, peerData := range peerList {
				peer := parsePeer(peerData)
				if peer.Name != "" && peer.IP != "" {
					nodeMap[peer.Name] = peer.IP
				}
			}
		}
	}

	// Convert to nodes with priorities
	priorityMap := map[string]int{
		"micklethefickle": 1,
		"beatapostapita":  2,
		"cloudserver1":    3,
		"cloudserver2":    4,
		"cloudserver3":    5,
	}

	for name, ip := range nodeMap {
		priority := priorityMap[name]
		if priority == 0 {
			priority = 99 // Unknown nodes get lowest priority
		}
		nodes = append(nodes, TailscaleNode{
			Name:        name,
			TailscaleIP: ip,
			Priority:    priority,
		})
	}

	return nodes, nil
}

func extractShortName(dnsName, hostName string) string {
	if dnsName != "" {
		return strings.Split(dnsName, ".")[0]
	}
	if hostName != "" {
		return strings.Split(hostName, ".")[0]
	}
	return ""
}

func parsePeer(peerData interface{}) struct {
	Name string
	IP   string
} {
	result := struct {
		Name string
		IP   string
	}{}

	if peerMap, ok := peerData.(map[string]interface{}); ok {
		if dnsName, ok := peerMap["DNSName"].(string); ok {
			result.Name = extractShortName(dnsName, "")
		} else if hostName, ok := peerMap["HostName"].(string); ok {
			result.Name = extractShortName("", hostName)
		}

		if tailscaleIPs, ok := peerMap["TailscaleIPs"].([]interface{}); ok && len(tailscaleIPs) > 0 {
			if ip, ok := tailscaleIPs[0].(string); ok {
				result.IP = ip
			}
		}
	}

	return result
}

// TailscaleStatus represents the JSON structure from tailscale status --json
type TailscaleStatus struct {
	Self *TailscaleSelf `json:"Self"`
	Peer interface{}    `json:"Peer"` // Can be map or array
}

type TailscaleSelf struct {
	DNSName      string   `json:"DNSName"`
	HostName     string   `json:"HostName"`
	TailscaleIPs []string `json:"TailscaleIPs"`
}

