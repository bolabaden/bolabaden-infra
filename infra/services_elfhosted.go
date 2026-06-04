package main

import (
	"fmt"
)

// defineServicesElfhosted returns services extracted from elfhosted K8s templates
// Excludes SaaS control/billing components, focuses on deployable application workloads
func defineServicesElfhosted(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// filebrowser
	services = append(services, Service{
		Name:          "filebrowser",
		Image:         "filebrowser/filebrowser:latest",
		ContainerName: "filebrowser",
		Hostname:      "filebrowser",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/filebrowser/data", configPath), Target: "/data", Type: "bind"},
			{Source: fmt.Sprintf("%s/filebrowser/config", configPath), Target: "/config", Type: "bind"},
			{Source: fmt.Sprintf("%s/backup", configPath), Target: "/storage/backup", Type: "bind"},
			{Source: fmt.Sprintf("%s/rclone", configPath), Target: "/storage/rclone", Type: "bind"},
			{Source: fmt.Sprintf("%s/symlinks", configPath), Target: "/storage/symlinks", Type: "bind"},
			{Source: fmt.Sprintf("%s/logs", configPath), Target: "/storage/logs", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                            "true",
			"traefik.enable":                                             "true",
			"traefik.http.routers.filebrowser.rule":                      fmt.Sprintf("Host(`filebrowser.%s`) || Host(`filebrowser.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.filebrowser.loadbalancer.server.port": "8080",
			"homepage.group":                                             "File Management",
			"homepage.name":                                              "Filebrowser",
			"homepage.icon":                                              "filebrowser.png",
			"homepage.href":                                              fmt.Sprintf("https://filebrowser.%s", domain),
			"homepage.description":                                       "Web-based file browser and file manager",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080 || exit 1"},
			Interval:    "10s",
			Timeout:     "1s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// gatus (using alternative image since twinproduction/gatus is marked bad)
	services = append(services, Service{
		Name:          "gatus",
		Image:         "ghcr.io/twinproduction/gatus:latest",
		ContainerName: "gatus",
		Hostname:      "gatus",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/gatus/config", configPath), Target: "/config", Type: "bind"},
		},
		Environment: map[string]string{
			"GATUS_CONFIG_PATH": fmt.Sprintf("%s/gatus/config/config.yaml", configPath),
			"SMTP_FROM":         getEnv("GATUS_SMTP_FROM", ""),
			"SMTP_PORT":         getEnv("GATUS_SMTP_PORT", "587"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                      "true",
			"traefik.enable":                                       "true",
			"traefik.http.routers.gatus.rule":                      fmt.Sprintf("Host(`gatus.%s`) || Host(`gatus.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.gatus.loadbalancer.server.port": "8080",
			"homepage.group":                                       "Monitoring",
			"homepage.name":                                        "Gatus",
			"homepage.icon":                                        "gatus.png",
			"homepage.href":                                        fmt.Sprintf("https://gatus.%s", domain),
			"homepage.description":                                 "Automated health status dashboard",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080 || exit 1"},
			Interval:    "10s",
			Timeout:     "1s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// homer
	services = append(services, Service{
		Name:          "homer",
		Image:         "b4bz/homer:latest",
		ContainerName: "homer",
		Hostname:      "homer",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/homer/config", configPath), Target: "/www/assets", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                      "true",
			"traefik.enable":                                       "true",
			"traefik.http.routers.homer.rule":                      fmt.Sprintf("Host(`homer.%s`) || Host(`homer.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.homer.loadbalancer.server.port": "8080",
			"homepage.group":                                       "Dashboards",
			"homepage.name":                                        "Homer",
			"homepage.icon":                                        "homer.png",
			"homepage.href":                                        fmt.Sprintf("https://homer.%s", domain),
			"homepage.description":                                 "A dead simple static homepage for your server",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080 || exit 1"},
			Interval:    "10s",
			Timeout:     "1s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// wizarr
	services = append(services, Service{
		Name:          "wizarr",
		Image:         "ghcr.io/elfhosted/wizarr:latest",
		ContainerName: "wizarr",
		Hostname:      "wizarr",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/wizarr/data", configPath), Target: "/data", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                       "true",
			"traefik.enable":                                        "true",
			"traefik.http.routers.wizarr.rule":                      fmt.Sprintf("Host(`wizarr.%s`) || Host(`wizarr.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.wizarr.loadbalancer.server.port": "5690",
			"homepage.group":                                        "Media Management",
			"homepage.name":                                         "Wizarr",
			"homepage.icon":                                         "wizarr.png",
			"homepage.href":                                         fmt.Sprintf("https://wizarr.%s", domain),
			"homepage.description":                                  "Automatic user invitation system for Plex, Jellyfin, and Emby",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:5690 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		Restart: "always",
	})

	// zurg (Real-Debrid Zurg)
	services = append(services, Service{
		Name:          "zurg",
		Image:         "ghcr.io/elfhosted/zurg-rc:latest",
		ContainerName: "zurg",
		Hostname:      "zurg",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/zurg/data", configPath), Target: "/data", Type: "bind"},
			{Source: fmt.Sprintf("%s/zurg/config", configPath), Target: "/config", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                     "true",
			"traefik.enable":                                      "true",
			"traefik.http.routers.zurg.rule":                      fmt.Sprintf("Host(`zurg.%s`) || Host(`zurg.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.zurg.loadbalancer.server.port": "9999",
			"homepage.group":                                      "Media Streaming",
			"homepage.name":                                       "Zurg",
			"homepage.icon":                                       "zurg.png",
			"homepage.href":                                       fmt.Sprintf("https://zurg.%s", domain),
			"homepage.description":                                "Real-Debrid WebDAV server for media streaming",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:9999/dav || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		Restart: "always",
	})

	// rclonefm (Rclone File Manager)
	services = append(services, Service{
		Name:          "rclonefm",
		Image:         "rclone/rclone:latest",
		ContainerName: "rclonefm",
		Hostname:      "rclonefm",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/rclonefm/config", configPath), Target: "/config", Type: "bind"},
			{Source: fmt.Sprintf("%s/rclonefm/data", configPath), Target: "/data", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                         "true",
			"traefik.enable":                                          "true",
			"traefik.http.routers.rclonefm.rule":                      fmt.Sprintf("Host(`rclonefm.%s`) || Host(`rclonefm.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.rclonefm.loadbalancer.server.port": "8080",
			"homepage.group":                                          "Cloud",
			"homepage.name":                                           "RcloneFM",
			"homepage.icon":                                           "rclone.png",
			"homepage.href":                                           fmt.Sprintf("https://rclonefm.%s", domain),
			"homepage.description":                                    "Rclone file manager web interface",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// rcloneui (Rclone UI)
	services = append(services, Service{
		Name:          "rcloneui",
		Image:         "rclone/rclone:latest",
		ContainerName: "rcloneui",
		Hostname:      "rcloneui",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/rcloneui/config", configPath), Target: "/config", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                         "true",
			"traefik.enable":                                          "true",
			"traefik.http.routers.rcloneui.rule":                      fmt.Sprintf("Host(`rcloneui.%s`) || Host(`rcloneui.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.rcloneui.loadbalancer.server.port": "5572",
			"homepage.group":                                          "Cloud",
			"homepage.name":                                           "RcloneUI",
			"homepage.icon":                                           "rclone.png",
			"homepage.href":                                           fmt.Sprintf("https://rcloneui.%s", domain),
			"homepage.description":                                    "Rclone web UI",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:5572 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// traefik-forward-auth
	services = append(services, Service{
		Name:          "traefik-forward-auth",
		Image:         "thomseddy/traefik-forward-auth:latest",
		ContainerName: "traefik-forward-auth",
		Hostname:      "traefik-forward-auth",
		Networks:      []string{"backend", "publicnet"},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                                     "true",
			"traefik.enable":                                                      "true",
			"traefik.http.routers.traefik-forward-auth.rule":                      fmt.Sprintf("Host(`traefik-forward-auth.%s`) || Host(`traefik-forward-auth.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.traefik-forward-auth.loadbalancer.server.port": "4181",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:4181 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// riven (note: image marked as bad in bad_images.txt, but including for completeness)
	services = append(services, Service{
		Name:          "riven",
		Image:         "ghcr.io/elfhosted/riven:latest",
		ContainerName: "riven",
		Hostname:      "riven",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/riven/data", configPath), Target: "/data", Type: "bind"},
			{Source: fmt.Sprintf("%s/riven/config", configPath), Target: "/config", Type: "bind"},
		},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                      "true",
			"traefik.enable":                                       "true",
			"traefik.http.routers.riven.rule":                      fmt.Sprintf("Host(`riven.%s`) || Host(`riven.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.riven.loadbalancer.server.port": "8080",
			"homepage.group":                                       "Media Management",
			"homepage.name":                                        "Riven",
			"homepage.icon":                                        "riven.png",
			"homepage.href":                                        fmt.Sprintf("https://riven.%s", domain),
			"homepage.description":                                 "Media management and organization tool",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		Restart: "always",
	})

	// riven-frontend
	services = append(services, Service{
		Name:          "riven-frontend",
		Image:         "ghcr.io/elfhosted/riven-frontend:latest",
		ContainerName: "riven-frontend",
		Hostname:      "riven-frontend",
		Networks:      []string{"backend", "publicnet"},
		Environment: map[string]string{
			"TZ": getEnv("TZ", "America/Chicago"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                               "true",
			"traefik.enable":                                                "true",
			"traefik.http.routers.riven-frontend.rule":                      fmt.Sprintf("Host(`riven-frontend.%s`) || Host(`riven-frontend.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.riven-frontend.loadbalancer.server.port": "3000",
			"homepage.group":                                                "Media Management",
			"homepage.name":                                                 "Riven Frontend",
			"homepage.icon":                                                 "riven.png",
			"homepage.href":                                                 fmt.Sprintf("https://riven-frontend.%s", domain),
			"homepage.description":                                          "Riven frontend web interface",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000 || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		Restart: "always",
	})

	return services
}
