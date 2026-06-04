package main

import (
	"fmt"

	infraconfig "cluster/infra/config"
)

// defineServicesWarp returns all services from compose/docker-compose.warp-nat-routing.yml
func defineServicesWarp(config *Config) []Service {
	// Get canonical config for image name resolution
	var cfg *infraconfig.Config
	if config.NewConfig != nil {
		cfg = config.NewConfig
	} else {
		cfg = infraconfig.MigrateFromOldConfig(
			config.Domain,
			config.StackName,
			config.ConfigPath,
			config.SecretsPath,
			config.RootPath,
		)
	}
	
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath

	services := []Service{}

	// warp-net-init - Creates the warp-nat-net network if it doesn't exist
	services = append(services, Service{
		Name:          "warp-net-init",
		Image:         "docker:cli",
		ContainerName: "warp-net-init",
		Networks:      []string{}, // network_mode: host
		Command: []string{
			"sh", "-c",
			`if ! docker network inspect ${DOCKER_NETWORK_NAME:-warp-nat-net} >/dev/null 2>&1; then
  echo "Creating network ${DOCKER_NETWORK_NAME:-warp-nat-net}..."
  docker network create \
    --driver=bridge \
    --attachable \
    -o com.docker.network.bridge.name=br_${DOCKER_NETWORK_NAME:-warp-nat-net} \
    -o com.docker.network.bridge.enable_ip_masquerade=false \
    --subnet=${WARP_NAT_NET_SUBNET:-10.0.2.0/24} \
    --gateway=${WARP_NAT_NET_GATEWAY:-10.0.2.1} \
    ${DOCKER_NETWORK_NAME:-warp-nat-net}
  echo "Network created successfully"
else
  echo "Network ${DOCKER_NETWORK_NAME:-warp-nat-net} already exists"
fi`,
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind", ReadOnly: true},
		},
		Restart: "no",
	})

	// warp-nat-gateway - The WARP container
	services = append(services, Service{
		Name:          "warp-nat-gateway",
		Image:         "docker.io/caomingjun/warp",
		ContainerName: "warp-nat-gateway",
		Hostname:      "warp-nat-gateway",
		Networks:      []string{"warp-nat-net"},
		Environment: map[string]string{
			"BETA_FIX_HOST_CONNECTIVITY": "false",
			"GOST_ARGS":                  fmt.Sprintf("-L :%s", getEnv("GOST_SOCKS5_PORT", "1080")),
			"WARP_ENABLE_NAT":            "false",
			"WARP_LICENSE_KEY_FILE":      "/run/secrets/warp-license-key",
			"WARP_SLEEP":                 "2",
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/warp-license-key.txt", secretsPath), Target: "/run/secrets/warp-license-key", Mode: "0400"},
		},
		Volumes: []VolumeMount{
			{Source: "warp-config-data", Target: "/var/lib/cloudflare-warp", Type: "volume"},
		},
		CapAdd: []string{"MKNOD", "AUDIT_WRITE", "NET_ADMIN"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", `sh -c "if curl -s https://cloudflare.com/cdn-cgi/trace | grep -qE '^warp=on|warp=plus$'; then echo \"Cloudflare WARP is active.\" && exit 0; else echo \"Cloudflare WARP is not active.\" && exit 1; fi"`},
			Interval:    "15s",
			Timeout:     "10s",
			Retries:     10,
			StartPeriod: "60s",
		},
		DependsOn:  []string{"warp-net-init"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
		// Note: device_cgroup_rules and sysctls need special handling
	})

	// warp_router - Monitor and setup for WARP NAT routing
	// Note: This has a complex build with inline Dockerfile and requires privileged mode
	// The setup and monitor scripts are quite complex and should be handled as configs
	services = append(services, Service{
		Name:          "warp_router",
		Image:         cfg.GetImageName("warp-router:latest"), // Build separately
		ContainerName: "warp_router",
		Networks:      []string{}, // network_mode: host
		Command:       []string{"/bin/bash", "/usr/local/bin/warp-monitor.sh"},
		Privileged:    true,
		Environment: map[string]string{
			"DOCKER_NETWORK_NAME":   getEnv("DOCKER_NETWORK_NAME", "warp-nat-net"),
			"WARP_CONTAINER_NAME":   getEnv("WARP_CONTAINER_NAME", "warp-nat-gateway"),
			"HOST_VETH_IP":          getEnv("HOST_VETH_IP", "169.254.100.1"),
			"CONT_VETH_IP":          getEnv("CONT_VETH_IP", "169.254.100.2"),
			"ROUTING_TABLE":         getEnv("ROUTING_TABLE", "warp-nat-routing"),
			"VETH_HOST":             getEnv("VETH_HOST", "veth-warp"),
			"ROUTER_CONTAINER_NAME": getEnv("ROUTER_CONTAINER_NAME", "warp_router"),
			"WARP_NAT_NET_SUBNET":   getEnv("WARP_NAT_NET_SUBNET", "10.0.2.0/24"),
			"WARP_NAT_NET_GATEWAY":  getEnv("WARP_NAT_NET_GATEWAY", "10.0.2.1"),
			"RETRY_SETUP_AFTER":     getEnv("RETRY_SETUP_AFTER", "12"),
			"SLEEP_INTERVAL":        getEnv("SLEEP_INTERVAL", "5"),
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
			{Source: "/etc/iproute2/rt_tables", Target: "/etc/iproute2/rt_tables", Type: "bind"},
			{Source: "/proc", Target: "/proc", Type: "bind"},
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", `docker run --rm --network ${DOCKER_NETWORK_NAME:-warp-nat-net} --entrypoint sh curlimages/curl -c 'if curl -s --max-time 4 https://cloudflare.com/cdn-cgi/trace | grep -qE "^warp=on|warp=plus$"; then exit 0; else exit 1; fi'`},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "20s",
		},
		DependsOn: []string{"warp-nat-gateway"},
		Restart:   "always",
		Build: &BuildConfig{
			Context:    fmt.Sprintf("%s/warp-router", configPath),
			Dockerfile: "Dockerfile",
		},
	})

	// ip-checker-warp - Test container to verify WARP is working
	services = append(services, Service{
		Name:          "ip-checker-warp",
		Image:         "docker.io/alpine",
		ContainerName: "ip-checker-warp",
		Networks:      []string{"warp-nat-net"},
		Command: []string{
			"/bin/sh", "-c",
			"apk add --no-cache curl ipcalc && while true; do echo \"$(date): $(curl -s --max-time 4 ifconfig.me)\"; sleep 5; done",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", `sh -c "if curl -s https://cloudflare.com/cdn-cgi/trace | grep -qE '^warp=on|warp=plus$'; then echo \"Cloudflare WARP is active.\" && exit 0; else echo \"Cloudflare WARP is not active.\" && exit 1; fi"`},
			Interval:    "15s",
			Timeout:     "10s",
			Retries:     10,
			StartPeriod: "60s",
		},
		Restart: "always",
	})

	return services
}
