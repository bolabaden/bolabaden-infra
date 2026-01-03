package main

import (
	"fmt"
)

// defineServicesHeadscale returns all services from compose/docker-compose.headscale.yml
func defineServicesHeadscale(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")
	certsPath := getEnv("CERTS_PATH", "./certs")

	services := []Service{}

	// headscale-server
	services = append(services, Service{
		Name:          "headscale-server",
		Image:         "docker.io/headscale/headscale",
		ContainerName: "headscale-server",
		Hostname:      "headscale-server",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/private/%s.key", certsPath, domain), Target: "/var/lib/headscale/private.key", Type: "bind"},
			{Source: fmt.Sprintf("%s/headscale/config", configPath), Target: "/etc/headscale", Type: "bind"},
			{Source: fmt.Sprintf("%s/headscale/lib", configPath), Target: "/var/lib/headscale", Type: "bind"},
			{Source: fmt.Sprintf("%s/headscale/run", configPath), Target: "/var/run/headscale", Type: "bind"},
		},
		Command: []string{"serve", "--config", "/etc/headscale/config.yaml"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"traefik.enable":                  "true",
			"traefik.http.middlewares.headscale-admin-redirect.redirectRegex.regex":        fmt.Sprintf("^https?://headscale(-server)?\\.(%s|%s\\.%s)/admin(.*)$", domain, tsHostname, domain),
			"traefik.http.middlewares.headscale-admin-redirect.redirectRegex.replacement":  fmt.Sprintf("https://headscale.%s/web$3", domain),
			"traefik.http.middlewares.headscale-admin-redirect.redirectRegex.permanent":    "false",
			"traefik.http.middlewares.headscale-server-redirect.redirectRegex.regex":       fmt.Sprintf("^https?://headscale-server\\.((?:%s|%s\\.%s))(.*)$", domain, tsHostname, domain),
			"traefik.http.middlewares.headscale-server-redirect.redirectRegex.replacement": "https://headscale.$1$2",
			"traefik.http.middlewares.headscale-server-redirect.redirectRegex.permanent":   "false",
			"traefik.http.routers.headscale-server.service":                                "headscale-server@docker",
			"traefik.http.routers.headscale-server.rule":                                   fmt.Sprintf("Host(`headscale-server.%s`) || Host(`headscale-server.%s.%s`) || Host(`headscale.%s`) || Host(`headscale.%s.%s`)", domain, tsHostname, domain, domain, tsHostname, domain),
			"traefik.http.routers.headscale-server.middlewares":                            "headscale-admin-redirect@docker,headscale-server-redirect@docker",
			"traefik.http.services.headscale-server.loadbalancer.server.port":              getEnv("HEADSCALE_HTTP_PORT", "8081"),
			"traefik.http.routers.headscale-metrics.service":                               "headscale-metrics@docker",
			"traefik.http.routers.headscale-metrics.rule":                                  fmt.Sprintf("(Host(`headscale.%s`) || Host(`headscale.%s.%s`)) && PathPrefix(`/metrics`)", domain, tsHostname, domain),
			"traefik.http.services.headscale-metrics.loadbalancer.server.port":             getEnv("HEADSCALE_METRICS_PORT", "8080"),
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget --no-verbose --tries=1 --spider http://127.0.0.1:%s/health || exit 1", getEnv("HEADSCALE_HTTP_PORT", "8081"))},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "20s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// headscale UI
	services = append(services, Service{
		Name:          "headscale",
		Image:         "ghcr.io/gurucomputing/headscale-ui",
		ContainerName: "headscale",
		Hostname:      "headscale",
		Networks:      []string{"backend", "publicnet"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                          "true",
			"traefik.enable":                                           "true",
			"traefik.http.routers.headscale.service":                   "headscale",
			"traefik.http.routers.headscale.rule":                      fmt.Sprintf("(Host(`headscale.%s`) || Host(`headscale.%s.%s`)) && (PathPrefix(`/web`) || PathPrefix(`/web/users.html`) || PathPrefix(`/web/groups.html`) || PathPrefix(`/web/devices.html`) || PathPrefix(`/web/settings.html`))", domain, tsHostname, domain),
			"traefik.http.services.headscale.loadbalancer.server.port": "8080",
			"homepage.group":                                           "Networking",
			"homepage.name":                                            "Headscale UI",
			"homepage.icon":                                            "headscale.png",
			"homepage.href":                                            fmt.Sprintf("https://headscale.%s/", domain),
			"homepage.description":                                     "Headscale UI is a web interface for Headscale, an open source implementation of Tailscale's Admin control panel.",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/ || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "20s",
		},
		DependsOn:  []string{"headscale-server"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
