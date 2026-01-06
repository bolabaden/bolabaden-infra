package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"

	"cluster/infra/api"
	"cluster/infra/cluster/gossip"
	"cluster/infra/cluster/raft"
	"cluster/infra/dns"
	"cluster/infra/failover"
	"cluster/infra/monitoring"
	"cluster/infra/tailscale"
	"cluster/infra/traefik"
)

var (
	domain           = flag.String("domain", getEnv("DOMAIN", "bolabaden.org"), "Domain name")
	nodeName         = flag.String("node-name", getEnv("TS_HOSTNAME", ""), "Node name (from TS_HOSTNAME)")
	bindAddr         = flag.String("bind-addr", "", "Address to bind to (Tailscale IP)")
	bindPort         = flag.Int("bind-port", 7946, "Port for gossip protocol")
	raftPort         = flag.Int("raft-port", 8300, "Port for Raft consensus")
	dataDir          = flag.String("data-dir", getEnv("DATA_DIR", "/opt/constellation/data"), "Data directory for Raft")
	configPath       = flag.String("config-path", getEnv("CONFIG_PATH", "/opt/constellation/volumes"), "Configuration path")
	secretsPath      = flag.String("secrets-path", getEnv("SECRETS_PATH", "/opt/constellation/secrets"), "Secrets path")
	httpProviderPort = flag.Int("http-provider-port", 8081, "Port for Traefik HTTP provider API")
	apiPort          = flag.Int("api-port", getEnvInt("API_PORT", 8080), "Port for REST API server")
)

func main() {
	flag.Parse()

	// Validate required parameters
	if *nodeName == "" {
		hostname, _ := os.Hostname()
		*nodeName = hostname
		log.Printf("Node name not provided, using hostname: %s", *nodeName)
	}

	// Get Tailscale IP
	tailscaleIP, err := tailscale.GetTailscaleIP()
	if err != nil {
		log.Fatalf("Failed to get Tailscale IP: %v", err)
	}

	if *bindAddr == "" {
		*bindAddr = tailscaleIP
	}

	// Get public IP (for DNS updates)
	publicIP := getPublicIP()

	// Get node priority (from environment or default)
	priority := getNodePriority(*nodeName)

	// Discover seed nodes via Tailscale
	seedNodes, err := tailscale.DiscoverPeers()
	if err != nil {
		log.Printf("Warning: failed to discover peers: %v", err)
		seedNodes = []string{}
	}

	// Initialize gossip cluster
	log.Printf("Initializing gossip cluster...")
	gossipConfig := &gossip.Config{
		NodeName:     *nodeName,
		BindAddr:     *bindAddr,
		BindPort:     *bindPort,
		PublicIP:     publicIP,
		TailscaleIP:  tailscaleIP,
		Priority:     priority,
		Capabilities: []string{},
		SeedNodes:    seedNodes,
	}

	gossipCluster, err := gossip.NewGossipCluster(gossipConfig)
	if err != nil {
		log.Fatalf("Failed to create gossip cluster: %v", err)
	}
	defer gossipCluster.Shutdown()

	// Initialize Raft consensus
	log.Printf("Initializing Raft consensus...")
	raftConfig := &raft.Config{
		NodeName:  *nodeName,
		DataDir:   *dataDir,
		BindAddr:  *bindAddr,
		BindPort:  *raftPort,
		SeedNodes: buildRaftSeedNodes(seedNodes, *raftPort),
		LogLevel:  "info",
	}

	consensusManager, err := raft.NewConsensusManager(raftConfig)
	if err != nil {
		log.Fatalf("Failed to create consensus manager: %v", err)
	}
	defer consensusManager.Shutdown()

	// Initialize lease manager
	leaseManager := raft.NewLeaseManager(consensusManager, *nodeName)
	defer leaseManager.Shutdown()

	// Initialize Cloudflare DNS reconciler
	log.Printf("Initializing Cloudflare DNS reconciler...")
	cfAPIToken := readSecret(*secretsPath, "cf-api-token.txt")
	cfZoneID := getEnv("CLOUDFLARE_ZONE_ID", "")

	dnsReconciler, err := dns.NewDNSReconciler(&dns.Config{
		APIToken:   cfAPIToken,
		ZoneID:     cfZoneID,
		Domain:     *domain,
		RateLimit:  4,
		BurstLimit: 10,
	})
	if err != nil {
		log.Fatalf("Failed to create DNS reconciler: %v", err)
	}

	dnsController := dns.NewController(dnsReconciler)

	// Register DNS lease callback on consensus manager
	consensusManager.RegisterLeaseCallback(raft.LeaseTypeDNSWriter, func(hasLease bool) {
		dnsController.SetLeaseOwnership(hasLease)
		if hasLease {
			// Update DNS records
			dnsController.UpdateLBLeader(publicIP)
			// Update per-node records from gossip state
			updateNodeDNSRecords(dnsController, gossipCluster)
		}
	})

	// Initialize Traefik HTTP provider
	log.Printf("Initializing Traefik HTTP provider...")
	httpProvider := traefik.NewHTTPProviderServer(
		gossipCluster.GetState(),
		*httpProviderPort,
		*domain,
		*nodeName,
	)

	// Start HTTP provider server
	go func() {
		if err := httpProvider.Start(); err != nil {
			log.Fatalf("HTTP provider server failed: %v", err)
		}
	}()

	// Main agent loop
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize Docker client for health monitoring
	dockerClient, err := client.NewClientWithOpts(client.FromEnv, client.WithVersion("1.44"))
	if err != nil {
		log.Fatalf("Failed to create Docker client: %v", err)
	}

	// Start service health monitoring
	go monitorServiceHealth(ctx, dockerClient, gossipCluster, *nodeName)

	// Start WARP health monitoring
	warpMonitor := monitoring.NewWarpMonitor(dockerClient, func(healthy bool) {
		// Broadcast WARP health to gossip
		gossipCluster.BroadcastWARPHealth(healthy)
	})
	go warpMonitor.Start(ctx)

	// Start LB leader management
	go manageLBLeader(ctx, leaseManager, dnsController, publicIP, gossipCluster, consensusManager, dockerClient)

	// Start periodic DNS reconciliation for all nodes
	go reconcileNodeDNS(ctx, dnsController, gossipCluster, consensusManager, *nodeName)

	// Initialize migration manager for enhanced failover
	log.Printf("Initializing migration manager...")
	migrationManager := failover.NewMigrationManager(dockerClient, gossipCluster.GetState(), *nodeName)

	// Load migration rules from configuration
	migrationRulesPath := getEnv("MIGRATION_RULES_PATH", "/opt/constellation/config/migration-rules.json")
	migrationRules, err := failover.LoadMigrationRules(migrationRulesPath)
	if err != nil {
		log.Printf("Warning: Failed to load migration rules: %v (using empty rules)", err)
		migrationRules = []failover.MigrationRule{}
	} else {
		log.Printf("Loaded %d migration rule(s) from %s", len(migrationRules), migrationRulesPath)
	}

	// Start migration monitoring with loaded rules
	go migrationManager.MonitorAndMigrate(ctx, migrationRules)

	// Initialize WebSocket server
	log.Printf("Initializing WebSocket server...")
	wsServer := api.NewWebSocketServer(gossipCluster, consensusManager)

	// Initialize and start REST API server (includes WebSocket endpoint)
	log.Printf("Initializing REST API server...")
	apiServer := api.NewServer(gossipCluster, consensusManager, migrationManager, wsServer, *apiPort)
	go func() {
		if err := apiServer.Start(); err != nil {
			log.Printf("API server failed: %v", err)
		}
	}()

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	log.Printf("Constellation Agent started successfully")
	log.Printf("  Node: %s", *nodeName)
	log.Printf("  Domain: %s", *domain)
	log.Printf("  Tailscale IP: %s", tailscaleIP)
	log.Printf("  Public IP: %s", publicIP)
	log.Printf("  Gossip port: %d", *bindPort)
	log.Printf("  Raft port: %d", *raftPort)
	log.Printf("  HTTP provider port: %d", *httpProviderPort)
	log.Printf("  API port: %d", *apiPort)

	<-sigCh
	log.Printf("Shutting down...")

	// Create shutdown context with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()

	// Cancel main context to stop all goroutines
	cancel()

	// Gracefully shutdown API server (includes WebSocket server)
	if err := apiServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("Error shutting down API server: %v", err)
	}

	// Additional shutdown is handled by defer statements for gossip, consensus, and lease manager
	log.Printf("Shutdown complete")
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		var result int
		if _, err := fmt.Sscanf(value, "%d", &result); err == nil {
			return result
		}
	}
	return defaultValue
}

func getPublicIP() string {
	// First check environment variable
	if ip := getEnv("PUBLIC_IP", ""); ip != "" {
		return ip
	}

	// Try to detect from external services
	ipServices := []string{
		"https://api.ipify.org",
		"https://ifconfig.me",
		"https://icanhazip.com",
		"https://checkip.amazonaws.com",
	}

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	for _, service := range ipServices {
		req, err := http.NewRequest("GET", service, nil)
		if err != nil {
			continue
		}

		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			body, err := io.ReadAll(resp.Body)
			if err != nil {
				continue
			}

			ip := strings.TrimSpace(string(body))
			if net.ParseIP(ip) != nil {
				log.Printf("Detected public IP: %s (from %s)", ip, service)
				return ip
			}
		}
	}

	// Fallback: try to get IP from default route interface
	if ip := getIPFromDefaultInterface(); ip != "" {
		log.Printf("Using IP from default interface: %s", ip)
		return ip
	}

	log.Printf("Warning: Could not detect public IP, using empty string")
	return ""
}

func getIPFromDefaultInterface() string {
	// Try to get IP from default route
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return ""
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

func getNodePriority(nodeName string) int {
	// Fast nodes (cloudserver1-3) get lower priority (higher priority)
	// Slow nodes get higher priority number (lower priority)
	if strings.Contains(nodeName, "cloudserver") {
		return 10
	}
	return 50 // Default for slower nodes
}

func buildRaftSeedNodes(seedNodes []string, raftPort int) []string {
	raftSeeds := make([]string, 0, len(seedNodes))
	for _, node := range seedNodes {
		// Assume seed nodes are Tailscale IPs, add Raft port
		raftSeeds = append(raftSeeds, fmt.Sprintf("%s:%d", node, raftPort))
	}
	return raftSeeds
}

func readSecret(secretsPath, filename string) string {
	path := fmt.Sprintf("%s/%s", secretsPath, filename)
	data, err := os.ReadFile(path)
	if err != nil {
		log.Printf("Warning: failed to read secret %s: %v", path, err)
		return ""
	}
	return strings.TrimSpace(string(data))
}

func monitorServiceHealth(ctx context.Context, dockerClient *client.Client, cluster *gossip.GossipCluster, nodeName string) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Query all containers
			containers, err := dockerClient.ContainerList(ctx, types.ContainerListOptions{
				All: true,
			})
			if err != nil {
				log.Printf("Failed to list containers for health check: %v", err)
				continue
			}

			// Check health of each container
			for _, container := range containers {
				// Skip containers without names or system containers
				if len(container.Names) == 0 {
					continue
				}

				containerName := strings.TrimPrefix(container.Names[0], "/")

				// Skip infrastructure containers
				if strings.HasPrefix(containerName, "constellation-") ||
					strings.HasPrefix(containerName, "traefik") ||
					strings.HasPrefix(containerName, "warp-") {
					continue
				}

				// Extract service name from container name (remove stack prefix if present)
				serviceName := containerName
				if idx := strings.LastIndex(containerName, "_"); idx > 0 {
					serviceName = containerName[idx+1:]
				}

				// Get container details for endpoints, networks, and health
				containerJSON, err := dockerClient.ContainerInspect(ctx, container.ID)
				if err != nil {
					log.Printf("Failed to inspect container %s: %v", containerName, err)
					continue
				}

				// Determine health status
				healthy := containerJSON.State.Running
				if containerJSON.State.Running && containerJSON.State.Health != nil {
					healthy = containerJSON.State.Health.Status == "healthy"
				}

				// Extract endpoints (ports)
				endpoints := make(map[string]string)
				for port, bindings := range containerJSON.NetworkSettings.Ports {
					if len(bindings) > 0 {
						endpoints[string(port)] = bindings[0].HostIP + ":" + bindings[0].HostPort
					}
				}

				// Extract networks
				networks := make([]string, 0, len(containerJSON.NetworkSettings.Networks))
				for netName := range containerJSON.NetworkSettings.Networks {
					networks = append(networks, netName)
				}

				// Broadcast service health
				cluster.BroadcastServiceHealth(serviceName, healthy, endpoints, networks)
			}
		}
	}
}

func manageLBLeader(ctx context.Context, leaseManager *raft.LeaseManager, dnsController *dns.Controller, publicIP string, cluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager, dockerClient *client.Client) {
	// Try to acquire LB leader lease
	if err := leaseManager.AcquireLBLeaderLease(); err != nil {
		log.Printf("Failed to acquire LB leader lease: %v", err)
	}

	// Register callback for lease changes on consensus manager
	consensusManager.RegisterLeaseCallback(raft.LeaseTypeLBLeader, func(hasLease bool) {
		if hasLease {
			log.Printf("Acquired LB leader lease")
			// Update DNS
			dnsController.UpdateLBLeader(publicIP)
			// Ensure Traefik has port bindings
			if err := ensureTraefikPortBindings(ctx, dockerClient); err != nil {
				log.Printf("Warning: Failed to ensure Traefik port bindings: %v", err)
			}
		} else {
			log.Printf("Lost LB leader lease")
			// Traefik continues running but DNS points elsewhere, so it won't receive traffic
			// We could remove port bindings, but keeping them allows quick failover
			log.Printf("Traefik will continue running but won't receive traffic (DNS points to new leader)")
		}
	})

	// Periodic lease renewal is handled by LeaseManager
}

// updateNodeDNSRecords updates DNS records for all nodes in the gossip state
func updateNodeDNSRecords(dnsController *dns.Controller, cluster *gossip.GossipCluster) {
	state := cluster.GetState()
	nodeIPs := make(map[string]string)

	// Collect node IPs from gossip state
	for nodeName, nodeInfo := range state.Nodes {
		if nodeInfo.PublicIP != "" {
			nodeIPs[nodeName] = nodeInfo.PublicIP
		}
	}

	// Update DNS records for all nodes via controller
	if len(nodeIPs) > 0 {
		dnsController.UpdateNodeIPs(nodeIPs)
		log.Printf("Requested DNS update for %d nodes", len(nodeIPs))
	}
}

// reconcileNodeDNS periodically reconciles DNS records for all nodes
func reconcileNodeDNS(ctx context.Context, dnsController *dns.Controller, cluster *gossip.GossipCluster, consensusManager *raft.ConsensusManager, currentNodeName string) {
	ticker := time.NewTicker(60 * time.Second) // Reconcile every minute
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Only reconcile if we hold the DNS writer lease
			lease := consensusManager.GetLease(raft.LeaseTypeDNSWriter)
			if lease != nil && lease.NodeName == currentNodeName {
				updateNodeDNSRecords(dnsController, cluster)
			}
		}
	}
}

// ensureTraefikPortBindings ensures Traefik container has port bindings for 80 and 443
func ensureTraefikPortBindings(ctx context.Context, dockerClient *client.Client) error {
	// Find Traefik container
	containers, err := dockerClient.ContainerList(ctx, types.ContainerListOptions{
		All:     true,
		Filters: filters.NewArgs(filters.Arg("name", "traefik")),
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	if len(containers) == 0 {
		log.Printf("Traefik container not found, it should be deployed via main.go")
		return nil // Traefik should be deployed separately
	}

	// Check if Traefik has the required port bindings
	containerID := containers[0].ID
	containerJSON, err := dockerClient.ContainerInspect(ctx, containerID)
	if err != nil {
		return fmt.Errorf("failed to inspect Traefik container: %w", err)
	}

	// Check port bindings
	hasPort80 := false
	hasPort443 := false

	if containerJSON.HostConfig != nil && containerJSON.HostConfig.PortBindings != nil {
		for port := range containerJSON.HostConfig.PortBindings {
			if port.Port() == "80" && port.Proto() == "tcp" {
				hasPort80 = true
			}
			if port.Port() == "443" && (port.Proto() == "tcp" || port.Proto() == "udp") {
				hasPort443 = true
			}
		}
	}

	if hasPort80 && hasPort443 {
		log.Printf("Traefik already has required port bindings (80, 443)")
		return nil
	}

	// Port bindings are missing - log a warning
	// Note: We can't dynamically change port bindings, container would need to be recreated
	// This is expected to be handled by the deployment tool (main.go)
	log.Printf("Warning: Traefik container missing port bindings (80: %v, 443: %v). Recreate container to add bindings.", hasPort80, hasPort443)
	return nil
}
