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
		Expose: []ExposePort{
			{Port: "27017", Protocol: "tcp"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/mongodb/data", configPath), Target: "/data/db", Type: "bind"},
		},
		Environment: map[string]string{},
		Labels: map[string]string{
			"traefik.enable":                                        "true",
			"traefik.tcp.routers.mongodb.rule":                      fmt.Sprintf("HostSNI(`mongodb.%s`) || HostSNI(`mongodb.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.tcp.routers.mongodb.service":                   "mongodb@docker",
			"traefik.tcp.routers.mongodb.tls.domains[0].main":       domain,
			"traefik.tcp.routers.mongodb.tls.domains[0].sans":       fmt.Sprintf("*.%s,%s.%s", domain, getEnv("TS_HOSTNAME", ""), domain),
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
	searxngPort := getEnv("SEARXNG_PORT", "8080")
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
			"SEARXNG_BASE_URL": getEnv("SEARXNG_INTERNAL_URL", fmt.Sprintf("http://searxng:%s", searxngPort)),
			"SEARXNG_SECRET":   getEnv("SEARXNG_SECRET", ""),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                        "true",
			"traefik.enable":                                         "true",
			"traefik.http.services.searxng.loadbalancer.server.port": searxngPort,
			"homepage.group":                                         "Search",
			"homepage.name":                                          "SearxNG",
			"homepage.icon":                                          "searxng.png",
			"homepage.href":                                          fmt.Sprintf("https://searxng.%s/", domain),
			"homepage.description":                                   "Privacy-focused metasearch that aggregates results from many sources without tracking",
			"kuma.searxng.http.name":                                 fmt.Sprintf("searxng.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.searxng.http.url":                                  fmt.Sprintf("https://searxng.%s", domain),
			"kuma.searxng.http.interval":                             "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget --no-verbose --tries=1 --spider http://127.0.0.1:%s/ || exit 1", searxngPort)},
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
		Expose: []ExposePort{
			{Port: getEnv("REDIS_PORT", "6379"), Protocol: "tcp"},
		},
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
			fmt.Sprintf("sysctl vm.overcommit_memory=1 &> /dev/null &&\nredis-server\n--appendonly yes\n--save 60 1\n--bind 0.0.0.0\n--port %s\n--requirepass ${REDIS_PASSWORD:?}", getEnv("REDIS_PORT", "6379")),
		},
		Labels: map[string]string{
			"traefik.enable":                                      "true",
			"traefik.tcp.routers.redis.rule":                      fmt.Sprintf("HostSNI(`redis.%s`) || HostSNI(`redis.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.tcp.routers.redis.service":                   "redis@docker",
			"traefik.tcp.routers.redis.tls.domains[0].main":       domain,
			"traefik.tcp.routers.redis.tls.domains[0].sans":       fmt.Sprintf("*.%s,%s.%s", domain, getEnv("TS_HOSTNAME", ""), domain),
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
			"traefik.http.routers.traefik.rule":                      fmt.Sprintf("Host(`traefik.%s`) || Host(`traefik.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.services.traefik.loadbalancer.server.port": "8080",
			"homepage.group":                                         "Infrastructure",
			"homepage.name":                                          "Traefik",
			"homepage.icon":                                          "traefik.png",
			"homepage.href":                                          fmt.Sprintf("https://traefik.%s/dashboard", domain),
			"homepage.widget.type":                                   "traefik",
			"homepage.widget.url":                                    "http://traefik:8080",
			"homepage.description":                                   "Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware",
			"kuma.traefik.http.name":                                 fmt.Sprintf("traefik.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
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
		DependsOn:  []string{"dockerproxy-ro"}, // Note: crowdsec dependency removed if not in included compose files
	})

	// Docker Proxy RO
	services = append(services, Service{
		Name:          "dockerproxy-ro",
		Image:         "docker.io/tecnativa/docker-socket-proxy",
		ContainerName: "dockerproxy-ro",
		Hostname:      "dockerproxy-ro",
		Networks:      []string{"default"},
		Privileged:    true,
		UserNSMode:    "host", // Required for userns-remap support
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ":           getEnv("TZ", "America/Chicago"),
			"PUID":         getEnv("PUID", "1001"),
			"PGID":         getEnv("PGID", "999"),
			"UMASK":        getEnv("UMASK", "002"),
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

	// Code Server
	services = append(services, Service{
		Name:          "code-server",
		Image:         "lscr.io/linuxserver/code-server",
		ContainerName: "code-server",
		Hostname:      "code-server",
		Networks:      []string{"backend", "publicnet"},
		Expose: []ExposePort{
			{Port: "8443", Protocol: "tcp"},
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
			{Source: fmt.Sprintf("%s/code-server/dev/config", configPath), Target: "/config", Type: "bind"},
			{Source: getEnv("ROOT_PATH", "."), Target: getEnv("CODESERVER_DEFAULT_WORKSPACE", "/workspace"), Type: "bind"},
		},
		Environment: map[string]string{
			"TZ":                 getEnv("TZ", "America/Chicago"),
			"PUID":               getEnv("PUID", "1001"),
			"PGID":               getEnv("PGID", "121"),
			"UMASK":              getEnv("UMASK", "002"),
			"HASHED_PASSWORD":    getEnv("CODESERVER_HASHED_PASSWORD", ""),
			"SUDO_PASSWORD_HASH": getEnv("CODESERVER_SUDO_PASSWORD_HASH", ""),
			"PWA_APPNAME":        fmt.Sprintf("code-server.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"DEFAULT_WORKSPACE":  getEnv("CODESERVER_DEFAULT_WORKSPACE", "/workspace"),
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.middlewares.codeserver-redirect.redirectRegex.regex":       fmt.Sprintf("^https?://codeserver\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.codeserver-redirect.redirectRegex.replacement": "https://code-server.$1$2",
			"traefik.http.middlewares.codeserver-redirect.redirectRegex.permanent":   "false",
			"traefik.http.routers.code-server.middlewares":                           "nginx-auth@file",
			"traefik.http.services.code-server.loadbalancer.server.port":             "8443",
			"traefik.http.routers.codeserver-redirect.rule":                          fmt.Sprintf("Host(`codeserver.%s`) || Host(`codeserver.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.codeserver-redirect.middlewares":                   "codeserver-redirect@docker",
			"traefik.http.routers.codeserver-redirect.service":                       "code-server@docker",
			"homepage.group":                 "Infrastructure",
			"homepage.name":                  "Code Dev",
			"homepage.icon":                  "code-server.png",
			"homepage.href":                  fmt.Sprintf("https://code-server.%s/", domain),
			"homepage.description":           "In-browser VS Code environment for editing and managing code on this server",
			"kuma.code-server.http.name":     fmt.Sprintf("code-server.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.code-server.http.url":      fmt.Sprintf("https://code-server.%s", domain),
			"kuma.code-server.http.interval": "60",
		},
		CPUs:           "2",
		MemLimit:       "4G",
		MemReservation: "200M",
		Restart:        "always",
		ExtraHosts:     []string{"host.docker.internal:host-gateway"},
	})

	// Session Manager
	services = append(services, Service{
		Name:          "session-manager",
		Image:         "alpine",
		ContainerName: "session-manager",
		Hostname:      "session-manager",
		Networks:      []string{"backend", "publicnet"},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/projects/kotor/kotorscript-session-manager/index.html", getEnv("ROOT_PATH", ".")), Target: "/tmp/templates/index.html", Mode: "0444"},
			{Source: fmt.Sprintf("%s/projects/kotor/kotorscript-session-manager/waiting.html", getEnv("ROOT_PATH", ".")), Target: "/tmp/templates/waiting.html", Mode: "0444"},
			{Source: fmt.Sprintf("%s/projects/kotor/kotorscript-session-manager/session_manager.py", getEnv("ROOT_PATH", ".")), Target: "/session_manager.py", Mode: "0444"},
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
			{Source: fmt.Sprintf("%s/extensions", configPath), Target: fmt.Sprintf("%s/extensions", configPath), Type: "bind"},
		},
		Environment: map[string]string{
			"DOMAIN":               domain,
			"SESSION_MANAGER_PORT": getEnv("SESSION_MANAGER_PORT", "8080"),
			"INACTIVITY_TIMEOUT":   "3600",
			"DEFAULT_WORKSPACE":    "/workspace",
			"EXT_PATH":             fmt.Sprintf("%s/extensions/holo-lsp-1.0.0.vsix", configPath),
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.middlewares.holoscripter-redirect.redirectRegex.regex":        fmt.Sprintf("^https?://holoscripter\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.holoscripter-redirect.redirectRegex.replacement":  "https://holoscript.$1$2",
			"traefik.http.middlewares.holoscripter-redirect.redirectRegex.permanent":    "false",
			"traefik.http.middlewares.kotorscripter-redirect.redirectRegex.regex":       fmt.Sprintf("^https?://kotorscripter\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.kotorscripter-redirect.redirectRegex.replacement": "https://holoscript.$1$2",
			"traefik.http.middlewares.kotorscripter-redirect.redirectRegex.permanent":   "false",
			"traefik.http.middlewares.kotorscript-redirect.redirectRegex.regex":         fmt.Sprintf("^https?://kotorscript\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.kotorscript-redirect.redirectRegex.replacement":   "https://holoscript.$1$2",
			"traefik.http.middlewares.kotorscript-redirect.redirectRegex.permanent":     "false",
			"traefik.http.middlewares.tslscript-redirect.redirectRegex.regex":           fmt.Sprintf("^https?://tslscript\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.tslscript-redirect.redirectRegex.replacement":     "https://holoscript.$1$2",
			"traefik.http.middlewares.tslscript-redirect.redirectRegex.permanent":       "false",
			"traefik.http.middlewares.kscript-redirect.redirectRegex.regex":             fmt.Sprintf("^https?://kscript\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.kscript-redirect.redirectRegex.replacement":       "https://holoscript.$1$2",
			"traefik.http.middlewares.kscript-redirect.redirectRegex.permanent":         "false",
			"traefik.http.middlewares.hololsp-redirect.redirectRegex.regex":             fmt.Sprintf("^https?://hololsp\\.((?:%s|%s\\.%s))(.*)$", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.middlewares.hololsp-redirect.redirectRegex.replacement":       "https://holoscript.$1$2",
			"traefik.http.middlewares.hololsp-redirect.redirectRegex.permanent":         "false",
			"traefik.http.routers.holoscript.rule":                                      fmt.Sprintf("Host(`holoscript.%s`) || Host(`holoscript.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.services.holoscript.loadbalancer.server.port":                 getEnv("KOTORSCRIPT_SESSION_MANAGER_PORT", "8080"),
			"traefik.http.routers.holoscripter-redirect.rule":                           fmt.Sprintf("Host(`holoscripter.%s`) || Host(`holoscripter.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.holoscripter-redirect.middlewares":                    "holoscripter-redirect@docker",
			"traefik.http.routers.holoscripter-redirect.service":                        "holoscript@docker",
			"traefik.http.routers.kotorscripter-redirect.rule":                          fmt.Sprintf("Host(`kotorscripter.%s`) || Host(`kotorscripter.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.kotorscripter-redirect.middlewares":                   "kotorscripter-redirect@docker",
			"traefik.http.routers.kotorscripter-redirect.service":                       "holoscript@docker",
			"traefik.http.routers.kotorscript-redirect.rule":                            fmt.Sprintf("Host(`kotorscript.%s`) || Host(`kotorscript.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.kotorscript-redirect.middlewares":                     "kotorscript-redirect@docker",
			"traefik.http.routers.kotorscript-redirect.service":                         "holoscript@docker",
			"traefik.http.routers.tslscript-redirect.rule":                              fmt.Sprintf("Host(`tslscript.%s`) || Host(`tslscript.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.tslscript-redirect.middlewares":                       "tslscript-redirect@docker",
			"traefik.http.routers.tslscript-redirect.service":                           "holoscript@docker",
			"traefik.http.routers.kscript-redirect.rule":                                fmt.Sprintf("Host(`kscript.%s`) || Host(`kscript.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.kscript-redirect.middlewares":                         "kscript-redirect@docker",
			"traefik.http.routers.kscript-redirect.service":                             "holoscript@docker",
			"traefik.http.routers.hololsp-redirect.rule":                                fmt.Sprintf("Host(`hololsp.%s`) || Host(`hololsp.%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.routers.hololsp-redirect.middlewares":                         "hololsp-redirect@docker",
			"traefik.http.routers.hololsp-redirect.service":                             "holoscript@docker",
		},
		Command: []string{
			"sh", "-c",
			"apk add python3 py3-pip docker-cli zip unzip && pip install fastapi uvicorn httpx websockets docker jinja2 python-multipart --break-system-packages --root-user-action=ignore && mkdir -p /tmp/templates && python3 session_manager.py",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget -qO- http://127.0.0.1:%s/health > /dev/null 2>&1 || exit 1", getEnv("KOTORSCRIPT_SESSION_MANAGER_PORT", "8080"))},
			Timeout:     "10s",
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Bolabaden NextJS
	services = append(services, Service{
		Name:          "bolabaden-nextjs",
		Image:         "docker.io/bolabaden/bolabaden-nextjs",
		ContainerName: "bolabaden-nextjs",
		Hostname:      "bolabaden-nextjs",
		Networks:      []string{"backend", "publicnet"},
		Expose: []ExposePort{
			{Port: "3000", Protocol: "tcp"},
		},
		Environment: map[string]string{
			"TZ":           getEnv("TZ", "America/Chicago"),
			"PUID":         getEnv("PUID", "1001"),
			"PGID":         getEnv("PGID", "999"),
			"UMASK":        getEnv("UMASK", "002"),
			"NODE_ENV":     "production",
			"PORT":         "3000",
			"HOSTNAME":     "0.0.0.0",
			"ALLOW_ORIGIN": "*",
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.middlewares.bolabaden-error-pages.errors.status":    "400-599",
			"traefik.http.middlewares.bolabaden-error-pages.errors.service":   "bolabaden-nextjs@docker",
			"traefik.http.middlewares.bolabaden-error-pages.errors.query":     "/api/error/{status}",
			"traefik.http.routers.bolabaden-nextjs.rule":                      fmt.Sprintf("Host(`%s`) || Host(`%s.%s`)", domain, getEnv("TS_HOSTNAME", ""), domain),
			"traefik.http.services.bolabaden-nextjs.loadbalancer.server.port": "3000",
			"kuma.bolabaden-nextjs.http.name":                                 fmt.Sprintf("%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.bolabaden-nextjs.http.url":                                  fmt.Sprintf("https://%s", domain),
			"kuma.bolabaden-nextjs.http.interval":                             "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget -qO- http://127.0.0.1:${PORT:-3000} > /dev/null 2>&1 || exit 1"},
			Timeout:     "10s",
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// Dozzle
	dozzlePort := getEnv("DOZZLE_PORT", "8080")
	services = append(services, Service{
		Name:          "dozzle",
		Image:         "docker.io/amir20/dozzle",
		ContainerName: "dozzle",
		Hostname:      "dozzle",
		Networks:      []string{"backend", "default", "publicnet"},
		Expose: []ExposePort{
			{Port: dozzlePort, Protocol: "tcp"},
		},
		Environment: map[string]string{
			"DOZZLE_NO_ANALYTICS":      getEnv("DOZZLE_NO_ANALYTICS", "true"),
			"DOZZLE_FILTER":            getEnv("DOZZLE_FILTER", ""),
			"DOZZLE_ENABLE_ACTIONS":    getEnv("DOZZLE_ENABLE_ACTIONS", "false"),
			"DOZZLE_AUTH_HEADER_NAME":  getEnv("DOZZLE_AUTH_HEADER_NAME", ""),
			"DOZZLE_AUTH_HEADER_USER":  getEnv("DOZZLE_AUTH_USER", ""),
			"DOZZLE_AUTH_HEADER_EMAIL": getEnv("DOZZLE_AUTH_EMAIL", ""),
			"DOZZLE_AUTH_PROVIDER":     getEnv("DOZZLE_AUTH_PROVIDER", "none"),
			"DOZZLE_LEVEL":             getEnv("DOZZLE_LEVEL", "info"),
			"DOZZLE_HOSTNAME":          getEnv("DOZZLE_HOSTNAME", ""),
			"DOZZLE_BASE":              getEnv("DOZZLE_BASE", "/"),
			"DOZZLE_ADDR":              fmt.Sprintf(":%s", dozzlePort),
			"DOZZLE_REMOTE_HOST":       "tcp://dockerproxy-ro:2375",
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.routers.dozzle.middlewares":               "nginx-auth@file",
			"traefik.http.services.dozzle.loadbalancer.server.port": dozzlePort,
			"homepage.group":            "System Monitoring",
			"homepage.name":             "Dozzle",
			"homepage.icon":             "dozzle.png",
			"homepage.href":             fmt.Sprintf("https://dozzle.%s", domain),
			"homepage.description":      "Real-time web UI for viewing Docker container logs across the host",
			"kuma.dozzle.http.name":     fmt.Sprintf("dozzle.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.dozzle.http.url":      fmt.Sprintf("https://dozzle.%s", domain),
			"kuma.dozzle.http.interval": "60",
		},
		DependsOn:  []string{"dockerproxy-ro"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Homepage
	services = append(services, Service{
		Name:          "homepage",
		Image:         "ghcr.io/gethomepage/homepage",
		ContainerName: "homepage",
		Hostname:      "homepage",
		Networks:      []string{"backend", "default", "publicnet"},
		Configs: []ConfigMount{
			{Source: "gethomepage-custom.css", Target: "/app/config/custom.css", Mode: "0777"}, // Config from docker-compose configs section
			{Source: "gethomepage-custom.js", Target: "/app/config/custom.js", Mode: "0777"},
			{Source: "gethomepage-docker.yaml", Target: "/app/config/docker.yaml", Mode: "0777"},
			{Source: "gethomepage-widgets.yaml", Target: "/app/config/widgets.yaml", Mode: "0777"},
			{Source: "gethomepage-settings.yaml", Target: "/app/config/settings.yaml", Mode: "0777"},
			{Source: "gethomepage-bookmarks.yaml", Target: "/app/config/bookmarks.yaml", Mode: "0777"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/homepage", configPath), Target: "/app/config", Type: "bind"},
		},
		Environment: map[string]string{
			"DOCKER_HOST":                  "tcp://dockerproxy-ro:2375",
			"HOMEPAGE_ALLOWED_HOSTS":       "*",
			"HOMEPAGE_VAR_TITLE":           "Bolabaden",
			"HOMEPAGE_VAR_SEARCH_PROVIDER": "duckduckgo",
			"HOMEPAGE_VAR_HEADER_STYLE":    "glass",
			"HOMEPAGE_VAR_THEME":           "dark",
			"HOMEPAGE_CUSTOM_CSS":          "/app/config/custom.css",
			"HOMEPAGE_CUSTOM_JS":           "/app/config/custom.js",
			"HOMEPAGE_VAR_WEATHER_CITY":    "Iowa City",
			"HOMEPAGE_VAR_WEATHER_LAT":     "41.661129",
			"HOMEPAGE_VAR_WEATHER_LONG":    "-91.5302",
			"HOMEPAGE_VAR_WEATHER_UNIT":    "fahrenheit",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                         "true",
			"traefik.enable":                                          "true",
			"traefik.http.services.homepage.loadbalancer.server.port": "3000",
			"kuma.homepage.http.name":                                 fmt.Sprintf("homepage.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.homepage.http.url":                                  fmt.Sprintf("https://homepage.%s", domain),
			"kuma.homepage.http.interval":                             "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget -qO- http://127.0.0.1:3000 > /dev/null 2>&1 || exit 1"},
			Interval:    "30s",
			Timeout:     "15s",
			Retries:     3,
			StartPeriod: "30s",
		},
		CPUs:                "0.25",
		MemReservation:      "128M",
		MemLimit:            "1G",
		DependsOn:           []string{"dockerproxy-ro"},
		DependsOnConditions: map[string]string{"dockerproxy-ro": "service_healthy"},
		Restart:             "always",
		ExtraHosts:          []string{"host.docker.internal:host-gateway"},
	})

	// Watchtower
	services = append(services, Service{
		Name:          "watchtower",
		Image:         "docker.io/containrrr/watchtower",
		ContainerName: "watchtower",
		Hostname:      "watchtower",
		Networks:      []string{"backend"},
		Configs: []ConfigMount{
			{Source: "watchtower-config.json", Target: "/config.json", Mode: "0444"}, // Config from docker-compose configs section (~/.docker/config.json)
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
		},
		Environment: map[string]string{
			"DOCKER_HOST":                        getEnv("DOCKER_HOST", "unix:///var/run/docker.sock"),
			"DOCKER_API_VERSION":                 getEnv("DOCKER_API_VERSION", "1.24"),
			"DOCKER_TLS_VERIFY":                  getEnv("DOCKER_TLS_VERIFY", "false"),
			"TZ":                                 getEnv("TZ", "America/Chicago"),
			"REPO_USER":                          getEnv("WATCHTOWER_REPO_USER", "bolabaden"),
			"REPO_PASS":                          getEnv("WATCHTOWER_REPO_PASS", getEnv("SUDO_PASSWORD", "")),
			"WATCHTOWER_INCLUDE_RESTARTING":      getEnv("WATCHTOWER_INCLUDE_RESTARTING", "true"),
			"WATCHTOWER_INCLUDE_STOPPED":         getEnv("WATCHTOWER_INCLUDE_STOPPED", "true"),
			"WATCHTOWER_REVIVE_STOPPED":          getEnv("WATCHTOWER_REVIVE_STOPPED", "false"),
			"WATCHTOWER_LABEL_ENABLE":            getEnv("WATCHTOWER_LABEL_ENABLE", "false"),
			"WATCHTOWER_DISABLE_CONTAINERS":      getEnv("WATCHTOWER_DISABLE_CONTAINERS", ""),
			"WATCHTOWER_LABEL_TAKE_PRECEDENCE":   getEnv("WATCHTOWER_LABEL_TAKE_PRECEDENCE", "true"),
			"WATCHTOWER_SCOPE":                   getEnv("WATCHTOWER_SCOPE", ""),
			"WATCHTOWER_POLL_INTERVAL":           getEnv("WATCHTOWER_POLL_INTERVAL", "86400"),
			"WATCHTOWER_SCHEDULE":                getEnv("WATCHTOWER_SCHEDULE", "0 0 6 * * *"),
			"WATCHTOWER_MONITOR_ONLY":            getEnv("WATCHTOWER_MONITOR_ONLY", "false"),
			"WATCHTOWER_NO_RESTART":              getEnv("WATCHTOWER_NO_RESTART", "false"),
			"WATCHTOWER_NO_PULL":                 getEnv("WATCHTOWER_NO_PULL", "false"),
			"WATCHTOWER_CLEANUP":                 getEnv("WATCHTOWER_CLEANUP", "true"),
			"WATCHTOWER_REMOVE_VOLUMES":          getEnv("WATCHTOWER_REMOVE_VOLUMES", "false"),
			"WATCHTOWER_ROLLING_RESTART":         getEnv("WATCHTOWER_ROLLING_RESTART", "false"),
			"WATCHTOWER_TIMEOUT":                 getEnv("WATCHTOWER_TIMEOUT", "10s"),
			"WATCHTOWER_RUN_ONCE":                getEnv("WATCHTOWER_RUN_ONCE", "false"),
			"WATCHTOWER_NO_STARTUP_MESSAGE":      getEnv("WATCHTOWER_NO_STARTUP_MESSAGE", "false"),
			"WATCHTOWER_WARN_ON_HEAD_FAILURE":    getEnv("WATCHTOWER_WARN_ON_HEAD_FAILURE", "auto"),
			"WATCHTOWER_HTTP_API_UPDATE":         getEnv("WATCHTOWER_HTTP_API_UPDATE", "false"),
			"WATCHTOWER_HTTP_API_TOKEN":          getEnv("WATCHTOWER_HTTP_API_TOKEN", ""),
			"WATCHTOWER_HTTP_API_PERIODIC_POLLS": getEnv("WATCHTOWER_HTTP_API_PERIODIC_POLLS", "false"),
			"WATCHTOWER_HTTP_API_METRICS":        getEnv("WATCHTOWER_HTTP_API_METRICS", "false"),
			"WATCHTOWER_DEBUG":                   getEnv("WATCHTOWER_DEBUG", "true"),
			"WATCHTOWER_TRACE":                   getEnv("WATCHTOWER_TRACE", "false"),
			"WATCHTOWER_LOG_LEVEL":               getEnv("WATCHTOWER_LOG_LEVEL", "debug"),
			"WATCHTOWER_LOG_FORMAT":              getEnv("WATCHTOWER_LOG_FORMAT", "Auto"),
			"NO_COLOR":                           getEnv("NO_COLOR", "false"),
			"WATCHTOWER_PORCELAIN":               getEnv("WATCHTOWER_PORCELAIN", ""),
			"WATCHTOWER_NOTIFICATION_URL":        getEnv("WATCHTOWER_NOTIFICATION_URL", ""),
			"WATCHTOWER_NOTIFICATION_REPORT":     getEnv("WATCHTOWER_NOTIFICATION_REPORT", "true"),
			"WATCHTOWER_NOTIFICATION_TEMPLATE": `{{- if .Report -}}
  {{- with .Report -}}
    {{- if ( or .Updated .Failed ) -}}
{{len .Scanned}} Scanned, {{len .Updated}} Updated, {{len .Failed}} Failed
      {{- range .Updated}}
  - {{.Name}} ({{.ImageName}}): {{.CurrentImageID.ShortID}} updated to {{.LatestImageID.ShortID}}
      {{- end -}}
      {{- range .Skipped}}
  - {{.Name}} ({{.ImageName}}): {{.State}}: {{.Error}}
      {{- end -}}
      {{- range .Failed}}
  - {{.Name}} ({{.ImageName}}): {{.State}}: {{.Error}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{range .Entries -}}{{.Message}}{{"\n"}}{{- end -}}
{{- end -}}`,
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Docker Proxy RW
	services = append(services, Service{
		Name:          "dockerproxy-rw",
		Image:         "lscr.io/linuxserver/socket-proxy",
		ContainerName: "dockerproxy-rw",
		Hostname:      "dockerproxy-rw",
		Networks:      []string{"backend", "default"},
		Privileged:    true,
		Ports: []PortMapping{
			{HostIP: "127.0.0.1", HostPort: "2375", ContainerPort: "2375", Protocol: "tcp"},
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ":             getEnv("TZ", "America/Chicago"),
			"PUID":           getEnv("PUID", "1001"),
			"PGID":           getEnv("PGID", "999"),
			"UMASK":          getEnv("UMASK", "002"),
			"ALLOW_START":    "1",
			"ALLOW_STOP":     "1",
			"ALLOW_RESTARTS": "1",
			"AUTH":           "1",
			"BUILD":          "1",
			"COMMIT":         "1",
			"CONFIGS":        "1",
			"CONTAINERS":     "1",
			"DISABLE_IPV6":   getEnv("DISABLE_IPV6", "0"),
			"DISTRIBUTION":   "1",
			"EVENTS":         "1",
			"EXEC":           "1",
			"IMAGES":         "1",
			"INFO":           "1",
			"LOG_LEVEL":      "info",
			"NETWORKS":       "1",
			"NODES":          "1",
			"PING":           "1",
			"PLUGINS":        "1",
			"POST":           "1",
			"SECRETS":        "1",
			"SERVICES":       "1",
			"SESSION":        "1",
			"SWARM":          "1",
			"SYSTEM":         "1",
			"TASKS":          "1",
			"VERSION":        "1",
			"VOLUMES":        "1",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Telemetry Auth
	services = append(services, Service{
		Name:          "telemetry-auth",
		Image:         "bolabaden/kotormodsync-telemetry-auth",
		ContainerName: "telemetry-auth-test",
		Hostname:      "telemetry-auth",
		User:          "0:0", // Run as root to read secrets
		Ports: []PortMapping{
			{HostPort: "8080", ContainerPort: "8080", Protocol: "tcp"},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/signing_secret.txt", secretsPath), Target: "/run/secrets/signing_secret", Mode: "0444"},
		},
		Environment: map[string]string{
			"AUTH_SERVICE_PORT":        "8080",
			"KOTORMODSYNC_SECRET_FILE": "/run/secrets/signing_secret",
			"REQUIRE_AUTH":             getEnv("REQUIRE_AUTH", "true"),
			"MAX_TIMESTAMP_DRIFT":      getEnv("MAX_TIMESTAMP_DRIFT", "300"),
			"LOG_LEVEL":                getEnv("LOG_LEVEL", "info"),
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1"},
			Interval:    "10s",
			Timeout:     "3s",
			Retries:     5,
			StartPeriod: "30s",
		},
		Restart: "unless-stopped",
	})

	// Portainer
	services = append(services, Service{
		Name:          "portainer",
		Image:         "docker.io/portainer/portainer-ce",
		ContainerName: "portainer",
		Hostname:      "portainer",
		Networks:      []string{"backend", "publicnet"},
		Expose: []ExposePort{
			{Port: "8000", Protocol: "tcp"},
			{Port: "9000", Protocol: "tcp"},
			{Port: "9443", Protocol: "tcp"},
		},
		Ports: []PortMapping{
			{HostIP: "127.0.0.1", HostPort: "9443", ContainerPort: "9443", Protocol: "tcp"},
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
			{Source: fmt.Sprintf("%s/portainer/data", configPath), Target: "/data", Type: "bind"},
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.routers.portainer.middlewares":               "nginx-auth@file",
			"traefik.http.routers.portainer.service":                   "portainer@docker",
			"traefik.http.services.portainer.loadbalancer.server.port": "9000",
			"kuma.portainer.http.name":                                 fmt.Sprintf("portainer.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.portainer.http.url":                                  fmt.Sprintf("https://portainer.%s", domain),
			"kuma.portainer.http.interval":                             "60",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// DNS Server
	services = append(services, Service{
		Name:          "dns-server",
		Image:         "docker.io/technitium/dns-server",
		ContainerName: "dns-server",
		Hostname:      fmt.Sprintf("dns-server.%s", domain),
		Networks:      []string{"publicnet"},
		Expose: []ExposePort{
			{Port: "53", Protocol: "udp"},
			{Port: "80", Protocol: "tcp"},
			{Port: "443", Protocol: "tcp"},
			{Port: "538", Protocol: "tcp"},
			{Port: "853", Protocol: "tcp"},
			{Port: "853", Protocol: "udp"},
			{Port: "8053", Protocol: "tcp"},
			{Port: "5380", Protocol: "tcp"},
			{Port: "53443", Protocol: "tcp"},
		},
		Ports: []PortMapping{
			{HostPort: "53", ContainerPort: "53", Protocol: "udp"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/dns-server/config", configPath), Target: "/etc/dns", Type: "bind"},
		},
		Labels: map[string]string{
			"traefik.enable": "true",
			"traefik.http.services.dns-server.loadbalancer.server.port": "5380",
			"homepage.group":                "Infrastructure",
			"homepage.name":                 "Technitium DNS Server",
			"homepage.icon":                 "dns-server.png",
			"homepage.href":                 fmt.Sprintf("https://dns-server.%s", domain),
			"homepage.description":          "DNS server used to resolve DNS queries",
			"kuma.dns-server.http.name":     fmt.Sprintf("dns-server.%s.%s", getEnv("TS_HOSTNAME", ""), domain),
			"kuma.dns-server.http.url":      fmt.Sprintf("https://dns-server.%s/", domain),
			"kuma.dns-server.http.interval": "60",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
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
