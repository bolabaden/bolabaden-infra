package main

import (
	"fmt"

	infraconfig "cluster/infra/config"
)

// defineServicesCoolifyProxy returns all services from compose/docker-compose.coolify-proxy.yml
func defineServicesCoolifyProxy(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")
	stackName := config.StackName

	// Determine Traefik Docker network name - match logic from DeployService
	// If StackName is empty, use just "publicnet", otherwise use "StackName_publicnet"
	traefikNetwork := "publicnet"
	if stackName != "" {
		traefikNetwork = stackName + "_publicnet"
	}

	services := []Service{}

	// cloudflare-ddns
	services = append(services, Service{
		Name:          "cloudflare-ddns",
		Image:         "docker.io/favonia/cloudflare-ddns:1",
		ContainerName: "cloudflare-ddns",
		Networks:      []string{}, // network_mode: host means no networks
		Environment: map[string]string{
			"TZ":                        getEnv("TZ", "America/Chicago"),
			"CLOUDFLARE_API_TOKEN_FILE": "/run/secrets/cloudflare-api-token",
			"DOMAINS":                   fmt.Sprintf("%s.%s,*.%s.%s", tsHostname, domain, tsHostname, domain),
			"PROXIED":                   fmt.Sprintf("is(%s)||is(*.%s)", domain, domain),
			"TTL":                       "1",
			"RECORD_COMMENT":            fmt.Sprintf("Updated by Cloudflare DDNS on server `%s.%s`", tsHostname, domain),
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/cf-api-token.txt", secretsPath), Target: "/run/secrets/cloudflare-api-token", Mode: "0400"},
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Restart: "always",
		// Note: network_mode: host and read_only/cap_drop/security_opt need special handling
	})

	// nginx-traefik-extensions
	services = append(services, Service{
		Name:          "nginx-traefik-extensions",
		Image:         "docker.io/nginx:alpine",
		ContainerName: "nginx-traefik-extensions",
		Hostname:      "nginx-traefik-extensions",
		Networks:      []string{"backend", "nginx_net"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/traefik/nginx-middlewares/auth", configPath), Target: "/etc/nginx/auth", Type: "bind", ReadOnly: true},
		},
		Environment: map[string]string{
			"TZ":               "America/Chicago",
			"NGINX_ACCESS_LOG": "/dev/stdout",
			"NGINX_ERROR_LOG":  "/dev/stderr",
			"NGINX_LOG_LEVEL":  "debug",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                                     "true",
			"traefik.http.middlewares.nginx-auth.forwardAuth.address":             "http://nginx-traefik-extensions:80/auth",
			"traefik.http.middlewares.nginx-auth.forwardAuth.trustForwardHeader":  "true",
			"traefik.http.middlewares.nginx-auth.forwardAuth.authResponseHeaders": "[\"X-Auth-Method\", \"X-Auth-Passed\", \"X-Middleware-Name\"]",
		},
		CPUs:           "1",
		MemLimit:       "1G",
		MemReservation: "6M",
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget -qO- http://127.0.0.1:80/health > /dev/null 2>&1 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "20s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
		// Note: configs need to be generated from content or file
	})

	// tinyauth
	services = append(services, Service{
		Name:          "tinyauth",
		Image:         "ghcr.io/steveiliop56/tinyauth:latest",
		ContainerName: "tinyauth",
		Hostname:      "auth",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/traefik/tinyauth", configPath), Target: "/data", Type: "bind"},
		},
		Environment: map[string]string{
			"SECRET_FILE":               "/run/secrets/tinyauth-secret",
			"APP_URL":                   fmt.Sprintf("https://auth.%s", domain),
			"USERS":                     getEnv("TINYAUTH_USERS", ""),
			"GOOGLE_CLIENT_ID":          getEnv("TINYAUTH_GOOGLE_CLIENT_ID", ""),
			"GOOGLE_CLIENT_SECRET_FILE": "/run/secrets/tinyauth-google-client-secret",
			"GITHUB_CLIENT_ID":          getEnv("TINYAUTH_GITHUB_CLIENT_ID", ""),
			"GITHUB_CLIENT_SECRET_FILE": "/run/secrets/tinyauth-github-client-secret",
			"SESSION_EXPIRY":            getEnv("TINYAUTH_SESSION_EXPIRY", "604800"),
			"COOKIE_SECURE":             getEnv("TINYAUTH_COOKIE_SECURE", "true"),
			"APP_TITLE":                 getEnv("TINYAUTH_APP_TITLE", domain),
			"LOGIN_MAX_RETRIES":         getEnv("TINYAUTH_LOGIN_MAX_RETRIES", "15"),
			"LOGIN_TIMEOUT":             getEnv("TINYAUTH_LOGIN_TIMEOUT", "300"),
			"OAUTH_AUTO_REDIRECT":       getEnv("TINYAUTH_OAUTH_AUTO_REDIRECT", "none"),
			"OAUTH_WHITELIST":           getEnv("TINYAUTH_OAUTH_WHITELIST", ""),
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/tinyauth-secret.txt", secretsPath), Target: "/run/secrets/tinyauth-secret", Mode: "0400"},
			{Source: fmt.Sprintf("%s/tinyauth-google-client-secret.txt", secretsPath), Target: "/run/secrets/tinyauth-google-client-secret", Mode: "0400"},
			{Source: fmt.Sprintf("%s/tinyauth-github-client-secret.txt", secretsPath), Target: "/run/secrets/tinyauth-github-client-secret", Mode: "0400"},
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                         "true",
			"traefik.enable":                                          "true",
			"traefik.http.services.tinyauth.loadbalancer.server.port": "3000",
			"traefik.http.routers.tinyauth.rule":                      fmt.Sprintf("Host(`auth.%s`) || Host(`auth.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.middlewares.tinyauth.forwardAuth.address":   "http://auth:3000/api/auth/traefik",
			"homepage.group":                                          "Security",
			"homepage.name":                                           "TinyAuth",
			"homepage.icon":                                           "https://tinyauth.app/img/logo.png",
			"homepage.href":                                           fmt.Sprintf("https://auth.%s/", domain),
			"homepage.description":                                    "Centralized login service (email, Google, GitHub) used by Traefik auth middleware and apps",
			"kuma.tinyauth.http.name":                                 fmt.Sprintf("auth.%s.%s", tsHostname, domain),
			"kuma.tinyauth.http.url":                                  fmt.Sprintf("https://auth.%s", domain),
			"kuma.tinyauth.http.interval":                             "60",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// crowdsec
	services = append(services, Service{
		Name:          "crowdsec",
		Image:         "docker.io/crowdsecurity/crowdsec:latest",
		ContainerName: "crowdsec",
		Hostname:      "crowdsec",
		Networks:      []string{"backend"},
		Environment: map[string]string{
			"UID":         getEnv("PUID", "1001"),
			"GID":         getEnv("PGID", "999"),
			"COLLECTIONS": "crowdsecurity/appsec-crs crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/whitelist-good-actors crowdsecurity/base-http-scenarios crowdsecurity/http-cve crowdsecurity/linux crowdsecurity/sshd",
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/crowdsec-lapi-key.txt", secretsPath), Target: "/run/secrets/crowdsec-lapi-key", Mode: "0400"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/traefik/crowdsec/data", configPath), Target: "/var/lib/crowdsec/data", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/crowdsec/config", configPath), Target: "/etc/crowdsec", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/logs", configPath), Target: "/var/log/traefik", Type: "bind", ReadOnly: true},
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"homepage.group":                  "Security",
			"homepage.name":                   "CrowdSec",
			"homepage.icon":                   "crowdsec.png",
			"homepage.description":            "IPS/IDS threat detection and prevention with bouncer plugin for Traefik",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "cscli version > /dev/null 2>&1 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "40s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// traefik
	// Use canonical config to build Traefik command
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
	traefikCommand := infraconfig.BuildTraefikCommand(cfg, tsHostname)
	
	// Override network name to match the computed traefikNetwork
	// Find and replace the network argument
	for i, arg := range traefikCommand {
		if len(arg) > 20 && arg[:21] == "--providers.docker.network=" {
			traefikCommand[i] = fmt.Sprintf("--providers.docker.network=%s", traefikNetwork)
			break
		}
	}

	services = append(services, Service{
		Name:          "traefik",
		Image:         "docker.io/traefik:latest",
		ContainerName: "traefik",
		Hostname:      "traefik",
		Networks:      []string{"publicnet", "nginx_net"},
		Ports: []PortMapping{
			{HostPort: "80", ContainerPort: "80", Protocol: "tcp"},
			{HostPort: "443", ContainerPort: "443", Protocol: "tcp"},
			{HostPort: "443", ContainerPort: "443", Protocol: "udp"},
		},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind", ReadOnly: true},
			{Source: fmt.Sprintf("%s/traefik/dynamic", configPath), Target: "/traefik/dynamic", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/certs", configPath), Target: "/certs", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/plugins-local", configPath), Target: "/plugins-local", Type: "bind"},
			{Source: fmt.Sprintf("%s/traefik/logs", configPath), Target: "/var/log/traefik", Type: "bind"},
		},
		Environment: map[string]string{
			"DOCKER_HOST":             getEnv("TRAEFIK_DOCKER_HOST", "unix:///var/run/docker.sock"),
			"DOCKER_API_VERSION":      getEnv("DOCKER_API_VERSION_OVERRIDE", "1.52"),
			"LETS_ENCRYPT_EMAIL":      getEnv("ACME_RESOLVER_EMAIL", ""),
			"CLOUDFLARE_EMAIL":        getEnv("CLOUDFLARE_EMAIL", ""),
			"CLOUDFLARE_API_KEY_FILE": "/run/secrets/cloudflare-api-key",
			"CLOUDFLARE_ZONE_ID":      getEnv("CLOUDFLARE_ZONE_ID", ""),
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/cf-api-key.txt", secretsPath), Target: "/run/secrets/cloudflare-api-key", Mode: "0400"},
		},
		Command: traefikCommand,
		CapAdd:  []string{"NET_ADMIN"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                        "true",
			"traefik.enable":                                         "true",
			"traefik.http.routers.traefik.service":                   "api@internal",
			"traefik.http.routers.traefik.rule":                      fmt.Sprintf("Host(`traefik.%s`) || Host(`traefik.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.traefik.loadbalancer.server.port": "8080",
			"homepage.group":                                         "Infrastructure",
			"homepage.name":                                          "Traefik",
			"homepage.icon":                                          "traefik.png",
			"homepage.href":                                          fmt.Sprintf("https://traefik.%s/dashboard", domain),
			"homepage.widget.type":                                   "traefik",
			"homepage.widget.url":                                    "http://traefik:8080",
			"homepage.description":                                   "Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware",
			"kuma.traefik.http.name":                                 fmt.Sprintf("traefik.%s.%s", tsHostname, domain),
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
		DependsOn:  []string{"crowdsec"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// whoami
	services = append(services, Service{
		Name:          "whoami",
		Image:         "docker.io/traefik/whoami:latest",
		ContainerName: "whoami",
		Hostname:      "whoami",
		Networks:      []string{"backend", "publicnet"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                       "true",
			"traefik.enable":                                        "true",
			"traefik.http.routers.whoami.service":                   "whoami@docker",
			"traefik.http.services.whoami.loadBalancer.server.port": "80",
			"homepage.group":                                        "Web Services",
			"homepage.name":                                         "whoami",
			"homepage.icon":                                         "whoami.png",
			"homepage.href":                                         fmt.Sprintf("https://whoami.%s", domain),
			"homepage.description":                                  "Request echo service used to verify reverse-proxy, headers, and auth middleware",
			"kuma.whoami.http.name":                                 fmt.Sprintf("whoami.%s.%s", tsHostname, domain),
			"kuma.whoami.http.url":                                  fmt.Sprintf("https://whoami.%s", domain),
			"kuma.whoami.http.interval":                             "60",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// logrotate-traefik
	services = append(services, Service{
		Name:          "logrotate-traefik",
		Image:         traefikCfg.GetImageName("logrotate-traefik"),
		ContainerName: "logrotate-traefik",
		Networks:      []string{}, // network_mode: none
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/traefik/logs", configPath), Target: "/var/log/traefik", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		CPUs:           "0.1",
		MemLimit:       "64M",
		MemReservation: "8M",
		Restart:        "always",
		Build: &BuildConfig{
			Context:    fmt.Sprintf("%s/reverse_proxy/logrotate-traefik", getEnv("SRC_PATH", "./projects")),
			Dockerfile: "Dockerfile",
		},
	})

	// autokuma
	services = append(services, Service{
		Name:          "autokuma",
		Image:         "ghcr.io/bigboot/autokuma",
		ContainerName: "autokuma",
		Hostname:      "autokuma",
		Networks:      []string{"backend"},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind", ReadOnly: true},
		},
		Environment: map[string]string{
			"AUTOKUMA__KUMA__URL":             fmt.Sprintf("https://uptimekuma.%s", domain),
			"AUTOKUMA__KUMA__USERNAME":        getEnv("AUTOKUMA__KUMA__USERNAME", "admin"),
			"AUTOKUMA__KUMA__PASSWORD":        getEnv("AUTOKUMA__KUMA__PASSWORD", ""),
			"AUTOKUMA__KUMA__CALL_TIMEOUT":    getEnv("AUTOKUMA__KUMA__CALL_TIMEOUT", "5"),
			"AUTOKUMA__KUMA__CONNECT_TIMEOUT": getEnv("AUTOKUMA__KUMA__CONNECT_TIMEOUT", "5"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
