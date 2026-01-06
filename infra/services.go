package main

import (
	"fmt"
	"path/filepath"

	infraconfig "cluster/infra/config"
)

// Define all services from docker-compose.yml
func defineServicesFromConfig(config *Config) []Service {
	domain := config.Domain
	// Resolve configPath relative to RootPath if configPath is relative
	configPath := config.ConfigPath
	if !filepath.IsAbs(configPath) && config.RootPath != "." {
		configPath = filepath.Join(config.RootPath, configPath)
	}
	// Resolve secretsPath relative to RootPath if secretsPath is relative
	secretsPath := config.SecretsPath
	if !filepath.IsAbs(secretsPath) && config.RootPath != "." {
		secretsPath = filepath.Join(config.RootPath, secretsPath)
	}
	// StackName is used in network naming and service definitions (see buildTraefikCommand and services_coolify_proxy.go)
	_ = config.StackName // Used in buildTraefikCommand and network naming

	services := []Service{}

	// Aggregate services from coolify-proxy stack
	services = append(services, defineServicesCoolifyProxy(config)...)

	// Aggregate services from WARP NAT routing stack
	services = append(services, defineServicesWarp(config)...)

	// Aggregate services from headscale stack
	services = append(services, defineServicesHeadscale(config)...)

	// Aggregate services from authentik stack
	services = append(services, defineServicesAuthentik(config)...)

	// Aggregate services from metrics stack
	services = append(services, defineServicesMetrics(config)...)

	// Aggregate services from unsend stack
	services = append(services, defineServicesUnsend(config)...)

	// Aggregate services from firecrawl stack
	services = append(services, defineServicesFirecrawl(config)...)

	// Aggregate services from wordpress stack
	services = append(services, defineServicesWordpress(config)...)

	// Aggregate services from llm stack
	services = append(services, defineServicesLLM(config)...)

	// Aggregate services from stremio stack
	services = append(services, defineServicesStremio(config)...)

	// Aggregate services from elfhosted K8s templates
	services = append(services, defineServicesElfhosted(config)...)

	// MongoDB
	services = append(services, Service{
		Name:          "mongodb",
		Image:         "docker.io/mongo",
		ContainerName: "mongodb",
		Hostname:      getEnv("MONGODB_HOSTNAME", "mongodb"),
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/mongodb/data", configPath), Target: "/data/db", Type: "bind"},
		},
		Environment: map[string]string{},
		Labels: map[string]string{
			"traefik.enable":                                        "true",
			"traefik.tcp.routers.mongodb.rule":                      fmt.Sprintf("HostSNI(`mongodb.%s`) || HostSNI(`mongodb.${TS_HOSTNAME}.%s`)", domain, domain),
			"traefik.tcp.routers.mongodb.service":                   "mongodb@docker",
			"traefik.tcp.routers.mongodb.tls.domains[0].main":       domain,
			"traefik.tcp.routers.mongodb.tls.domains[0].sans":       fmt.Sprintf("*.%s,${TS_HOSTNAME}.%s", domain, domain),
			"traefik.tcp.routers.mongodb.tls.passthrough":           "true",
			"traefik.tcp.services.mongodb.loadbalancer.server.port": "27017",
			"traefik.tcp.services.mongodb.loadbalancer.server.tls":  "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "mongosh 127.0.0.1:27017/test --quiet --eval 'db.runCommand(\"ping\").ok' > /dev/null 2>&1 || exit 1"},
			Interval:    "10s",
			Timeout:     "10s",
			Retries:     5,
			StartPeriod: "40s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// SearXNG
	services = append(services, Service{
		Name:          "searxng",
		Image:         "docker.io/searxng/searxng",
		ContainerName: "searxng",
		Hostname:      "searxng",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/searxng/config", configPath), Target: "/etc/searxng", Type: "bind"},
			{Source: fmt.Sprintf("%s/searxng/data", configPath), Target: "/var/cache/searxng", Type: "bind"},
		},
		Environment: map[string]string{
			"SEARXNG_BASE_URL": fmt.Sprintf("http://searxng:%s", getEnv("SEARXNG_PORT", "8080")),
			"SEARXNG_SECRET":   getEnv("SEARXNG_SECRET", ""),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                        "true",
			"traefik.enable":                                         "true",
			"traefik.http.services.searxng.loadbalancer.server.port": getEnv("SEARXNG_PORT", "8080"),
			"homepage.group":                                         "Search",
			"homepage.name":                                          "SearxNG",
			"homepage.icon":                                          "searxng.png",
			"homepage.href":                                          fmt.Sprintf("https://searxng.%s/", domain),
			"homepage.description":                                   "Privacy-focused metasearch that aggregates results from many sources without tracking",
			"kuma.searxng.http.name":                                 fmt.Sprintf("searxng.${TS_HOSTNAME}.%s", domain),
			"kuma.searxng.http.url":                                  fmt.Sprintf("https://searxng.%s", domain),
			"kuma.searxng.http.interval":                             "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget --no-verbose --tries=1 --spider http://127.0.0.1:%s/ || exit 1", getEnv("SEARXNG_PORT", "8080"))},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Redis
	services = append(services, Service{
		Name:          "redis",
		Image:         "docker.io/redis:alpine",
		ContainerName: "redis",
		Hostname:      "redis",
		Networks:      []string{"backend", "publicnet"},
		Ports: []PortMapping{
			{HostPort: getEnv("REDIS_PORT", "6379"), ContainerPort: getEnv("REDIS_PORT", "6379"), Protocol: "tcp"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/redis", configPath), Target: "/data", Type: "bind"},
		},
		Privileged: true,
		Environment: map[string]string{
			"REDIS_HOST":     getEnv("REDIS_HOSTNAME", "redis"),
			"REDIS_PORT":     getEnv("REDIS_PORT", "6379"),
			"REDIS_DATABASE": getEnv("REDIS_DATABASE", "0"),
			"REDIS_USERNAME": getEnv("REDIS_USERNAME", "default"),
			"REDIS_PASSWORD": getEnv("REDIS_PASSWORD", "redis"),
		},
		Command: []string{
			"sh", "-c",
			fmt.Sprintf("sysctl vm.overcommit_memory=1 &> /dev/null && redis-server --appendonly yes --save 60 1 --bind 0.0.0.0 --port %s --requirepass ${REDIS_PASSWORD}", getEnv("REDIS_PORT", "6379")),
		},
		Labels: map[string]string{
			"traefik.enable":                                      "true",
			"traefik.tcp.routers.redis.rule":                      fmt.Sprintf("HostSNI(`redis.%s`) || HostSNI(`redis.${TS_HOSTNAME}.%s`)", domain, domain),
			"traefik.tcp.routers.redis.service":                   "redis@docker",
			"traefik.tcp.routers.redis.tls.domains[0].main":       domain,
			"traefik.tcp.routers.redis.tls.domains[0].sans":       fmt.Sprintf("*.%s,${TS_HOSTNAME}.%s", domain, domain),
			"traefik.tcp.routers.redis.tls.passthrough":           "true",
			"traefik.tcp.services.redis.loadbalancer.server.port": getEnv("REDIS_PORT", "6379"),
			"traefik.tcp.services.redis.loadbalancer.server.tls":  "true",
			"osvc.l4.enable":                                      "true",
			"osvc.l4.port":                                        getEnv("REDIS_PORT", "6379"),
			"osvc.l4.check":                                       "redis",
		},
		Healthcheck: &Healthcheck{
			Test:     []string{"CMD-SHELL", "redis-cli ping > /dev/null 2>&1 || exit 1"},
			Interval: "10s",
			Timeout:  "5s",
		},
		CPUs:           "0.5",
		MemReservation: "200M",
		MemLimit:       "4G",
		Restart:        "always",
		ExtraHosts:     []string{"host.docker.internal:host-gateway"},
	})

	// Traefik - Critical ingress service
	services = append(services, Service{
		Name:          "traefik",
		Image:         "docker.io/traefik:latest",
		ContainerName: "traefik",
		Hostname:      "traefik",
		Networks:      []string{"default", "nginx_net", "publicnet"},
		Ports: []PortMapping{
			{HostPort: "80", ContainerPort: "80", Protocol: "tcp"},
			{HostPort: "443", ContainerPort: "443", Protocol: "tcp"},
			{HostPort: "443", ContainerPort: "443", Protocol: "udp"},
		},
		Volumes: []VolumeMount{
			{Source: "/var/run/docker.sock", Target: "/var/run/docker.sock", Type: "bind", ReadOnly: true},
			{Source: fmt.Sprintf("%s/traefik/dynamic", configPath), Target: "/traefik/dynamic", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/certs", configPath), Target: "/certs", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/plugins-local", configPath), Target: "/plugins-local", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/logs", configPath), Target: "/var/log/traefik", Type: "bind"},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/cf-api-key.txt", secretsPath), Target: "/run/secrets/cloudflare-api-key", Mode: "0444"},
		},
		Environment: map[string]string{
			"DOCKER_HOST":             getEnv("TRAEFIK_DOCKER_HOST", "unix:///var/run/docker.sock"),
			"DOCKER_API_VERSION":      getEnv("DOCKER_API_VERSION_OVERRIDE", "1.52"),
			"LETS_ENCRYPT_EMAIL":      getEnv("ACME_RESOLVER_EMAIL", ""),
			"CLOUDFLARE_EMAIL":        getEnv("CLOUDFLARE_EMAIL", ""),
			"CLOUDFLARE_API_KEY_FILE": "/run/secrets/cloudflare-api-key",
			"CLOUDFLARE_ZONE_ID":      getEnv("CLOUDFLARE_ZONE_ID", ""),
		},
		Command: buildTraefikCommand(config),
		Labels: map[string]string{
			"traefik.enable":                                         "true",
			"traefik.http.routers.traefik.service":                   "api@internal",
			"traefik.http.routers.traefik.rule":                      fmt.Sprintf("Host(`traefik.%s`) || Host(`traefik.${TS_HOSTNAME}.%s`)", domain, domain),
			"traefik.http.services.traefik.loadbalancer.server.port": "8080",
			"homepage.group":                                         "Infrastructure",
			"homepage.name":                                          "Traefik",
			"homepage.icon":                                          "traefik.png",
			"homepage.href":                                          fmt.Sprintf("https://traefik.%s/dashboard", domain),
			"homepage.widget.type":                                   "traefik",
			"homepage.widget.url":                                    "http://traefik:8080",
			"homepage.description":                                   "Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware",
			"kuma.traefik.http.name":                                 fmt.Sprintf("traefik.${TS_HOSTNAME}.%s", domain),
			"kuma.traefik.http.url":                                  fmt.Sprintf("https://traefik.%s/dashboard", domain),
			"kuma.traefik.http.interval":                             "20",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "traefik healthcheck --ping"},
			Interval:    "10s",
			Timeout:     "3s",
			Retries:     3,
			StartPeriod: "10s",
		},
		CapAdd:     []string{"NET_ADMIN"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
		DependsOn:  []string{"dockerproxy-ro", "crowdsec"},
	})

	// Docker Proxy RO
	services = append(services, Service{
		Name:          "dockerproxy-ro",
		Image:         "docker.io/tecnativa/docker-socket-proxy",
		ContainerName: "dockerproxy-ro",
		Hostname:      "dockerproxy-ro",
		Networks:      []string{"default"},
		Privileged:    true,
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
		},
		Environment: map[string]string{
			"CONTAINERS":   "1",
			"EVENTS":       "1",
			"INFO":         "1",
			"DISABLE_IPV6": getEnv("DISABLE_IPV6", "0"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget -qO- http://127.0.0.1:2375/_ping > /dev/null 2>&1 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "10s",
		},
		Restart: "always",
	})

	return services
}

func buildTraefikCommand(config *Config) []string {
	// Use canonical config if available, otherwise create one
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
	
	// Get Tailscale hostname from environment
	tsHostname := getEnv("TS_HOSTNAME", "")
	
	// Use the canonical BuildTraefikCommand function
	return infraconfig.BuildTraefikCommand(cfg, tsHostname)
}
