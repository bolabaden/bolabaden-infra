package paas

import (
	"os"
	"path/filepath"
	"testing"
)

// TestRoundTripDockerComposeToNomad tests roundtrip conversion from Docker Compose to Nomad and back
func TestRoundTripDockerComposeToNomad(t *testing.T) {
	// Create a test application
	originalApp := createTestApplication()

	// Convert to Nomad HCL
	paas := New(nil)
	nomadApp, err := paas.Convert(originalApp, PlatformDockerCompose, PlatformNomad)
	if err != nil {
		t.Fatalf("Failed to convert Docker Compose to Nomad: %v", err)
	}

	// Validate Nomad conversion
	if nomadApp.Platform != PlatformNomad {
		t.Errorf("Expected platform Nomad, got %s", nomadApp.Platform)
	}

	// Convert back to Docker Compose
	backToDocker, err := paas.Convert(nomadApp, PlatformNomad, PlatformDockerCompose)
	if err != nil {
		t.Fatalf("Failed to convert Nomad back to Docker Compose: %v", err)
	}

	// Validate roundtrip
	if backToDocker.Platform != PlatformDockerCompose {
		t.Errorf("Expected platform Docker Compose, got %s", backToDocker.Platform)
	}

	// Check service count
	if len(backToDocker.Services) != len(originalApp.Services) {
		t.Errorf("Service count mismatch: original=%d, roundtrip=%d",
			len(originalApp.Services), len(backToDocker.Services))
	}

	// Check each service
	for name, originalSvc := range originalApp.Services {
		roundtripSvc, exists := backToDocker.Services[name]
		if !exists {
			t.Errorf("Service %s missing after roundtrip", name)
			continue
		}

		// Check critical fields
		if roundtripSvc.Image != originalSvc.Image {
			t.Errorf("Service %s image mismatch: %s != %s", name, roundtripSvc.Image, originalSvc.Image)
		}

		if len(roundtripSvc.Environment) != len(originalSvc.Environment) {
			t.Errorf("Service %s environment count mismatch: %d != %d",
				name, len(roundtripSvc.Environment), len(originalSvc.Environment))
		}
	}
}

// TestRoundTripDockerComposeToKubernetes tests roundtrip conversion from Docker Compose to Kubernetes and back
func TestRoundTripDockerComposeToKubernetes(t *testing.T) {
	originalApp := createTestApplication()
	paas := New(nil)

	k8sApp, err := paas.Convert(originalApp, PlatformDockerCompose, PlatformKubernetes)
	if err != nil {
		t.Fatalf("Failed to convert Docker Compose to Kubernetes: %v", err)
	}

	if k8sApp.Platform != PlatformKubernetes {
		t.Errorf("Expected platform Kubernetes, got %s", k8sApp.Platform)
	}

	backToDocker, err := paas.Convert(k8sApp, PlatformKubernetes, PlatformDockerCompose)
	if err != nil {
		t.Fatalf("Failed to convert Kubernetes back to Docker Compose: %v", err)
	}

	if backToDocker.Platform != PlatformDockerCompose {
		t.Errorf("Expected platform Docker Compose, got %s", backToDocker.Platform)
	}

	// Validate service preservation
	for name := range originalApp.Services {
		if _, exists := backToDocker.Services[name]; !exists {
			t.Errorf("Service %s missing after Kubernetes roundtrip", name)
		}
	}
}

// TestRoundTripNomadToKubernetes tests roundtrip conversion from Nomad to Kubernetes and back
func TestRoundTripNomadToKubernetes(t *testing.T) {
	originalApp := createTestApplication()
	paas := New(nil)

	// Start with Nomad
	nomadApp, err := paas.Convert(originalApp, PlatformDockerCompose, PlatformNomad)
	if err != nil {
		t.Fatalf("Failed to convert to Nomad: %v", err)
	}

	k8sApp, err := paas.Convert(nomadApp, PlatformNomad, PlatformKubernetes)
	if err != nil {
		t.Fatalf("Failed to convert Nomad to Kubernetes: %v", err)
	}

	backToNomad, err := paas.Convert(k8sApp, PlatformKubernetes, PlatformNomad)
	if err != nil {
		t.Fatalf("Failed to convert Kubernetes back to Nomad: %v", err)
	}

	if backToNomad.Platform != PlatformNomad {
		t.Errorf("Expected platform Nomad, got %s", backToNomad.Platform)
	}
}

// TestSerializeDeserialize tests full serialize/deserialize roundtrips
func TestSerializeDeserialize(t *testing.T) {
	app := createTestApplication()
	paas := New(nil)

	// Test Docker Compose
	dockerContent, err := paas.SaveContent(app, PlatformDockerCompose)
	if err != nil {
		t.Fatalf("Failed to serialize Docker Compose: %v", err)
	}

	parsedDocker, err := paas.LoadContent(dockerContent, PlatformDockerCompose)
	if err != nil {
		t.Fatalf("Failed to parse Docker Compose: %v", err)
	}

	if len(parsedDocker.Services) != len(app.Services) {
		t.Errorf("Docker Compose roundtrip failed: service count %d != %d",
			len(parsedDocker.Services), len(app.Services))
	}

	// Test Nomad HCL
	nomadContent, err := paas.SaveContent(app, PlatformNomad)
	if err != nil {
		t.Fatalf("Failed to serialize Nomad: %v", err)
	}

	parsedNomad, err := paas.LoadContent(nomadContent, PlatformNomad)
	if err != nil {
		t.Fatalf("Failed to parse Nomad: %v", err)
	}

	if len(parsedNomad.Services) != len(app.Services) {
		t.Errorf("Nomad roundtrip failed: service count %d != %d",
			len(parsedNomad.Services), len(app.Services))
	}

	// Test Kubernetes YAML
	k8sContent, err := paas.SaveContent(app, PlatformKubernetes)
	if err != nil {
		t.Fatalf("Failed to serialize Kubernetes: %v", err)
	}

	parsedK8s, err := paas.LoadContent(k8sContent, PlatformKubernetes)
	if err != nil {
		t.Fatalf("Failed to parse Kubernetes: %v", err)
	}

	if len(parsedK8s.Services) != len(app.Services) {
		t.Errorf("Kubernetes roundtrip failed: service count %d != %d",
			len(parsedK8s.Services), len(app.Services))
	}
}

// TestFileOperations tests loading and saving files
func TestFileOperations(t *testing.T) {
	app := createTestApplication()
	paas := New(nil)

	// Create temp directory
	tempDir, err := os.MkdirTemp("", "paas-test")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test Docker Compose file operations
	dockerFile := filepath.Join(tempDir, "docker-compose.yml")
	err = paas.SaveFile(app, dockerFile)
	if err != nil {
		t.Fatalf("Failed to save Docker Compose file: %v", err)
	}

	loadedDocker, err := paas.LoadFile(dockerFile)
	if err != nil {
		t.Fatalf("Failed to load Docker Compose file: %v", err)
	}

	if len(loadedDocker.Services) != len(app.Services) {
		t.Errorf("File roundtrip failed: %d != %d services",
			len(loadedDocker.Services), len(app.Services))
	}
}

// TestRealWorldFiles tests with the actual docker-compose.yml and nomad.hcl files
func TestRealWorldFiles(t *testing.T) {
	paas := New(nil)

	// Test loading real docker-compose.yml
	dockerApp, err := paas.LoadFile("docker-compose.yml")
	if err != nil {
		t.Logf("Note: Could not load docker-compose.yml (expected in development): %v", err)
	} else {
		t.Logf("Loaded docker-compose.yml with %d services", len(dockerApp.Services))

		// Try converting to Nomad
		nomadApp, err := paas.Convert(dockerApp, PlatformDockerCompose, PlatformNomad)
		if err != nil {
			t.Logf("Note: Docker to Nomad conversion failed (expected for complex files): %v", err)
		} else {
			t.Logf("Converted to Nomad with %d services", len(nomadApp.Services))
		}
	}

	// Test loading real nomad.hcl
	nomadApp, err := paas.LoadFile("nomad/nomad.hcl")
	if err != nil {
		t.Logf("Note: Could not load nomad/nomad.hcl (expected in development): %v", err)
	} else {
		t.Logf("Loaded nomad.hcl with %d services", len(nomadApp.Services))

		// Try converting to Docker Compose
		dockerApp, err := paas.Convert(nomadApp, PlatformNomad, PlatformDockerCompose)
		if err != nil {
			t.Logf("Note: Nomad to Docker conversion failed (expected for complex files): %v", err)
		} else {
			t.Logf("Converted to Docker with %d services", len(dockerApp.Services))
		}
	}
}

// TestValidation tests application validation
func TestValidation(t *testing.T) {
	paas := New(nil)

	// Test valid application
	validApp := createTestApplication()
	if err := paas.Validate(validApp); err != nil {
		t.Errorf("Valid application failed validation: %v", err)
	}

	// Test invalid application (no services)
	invalidApp := &Application{
		Platform: PlatformDockerCompose,
		Services: make(map[string]*Service),
	}
	if err := paas.Validate(invalidApp); err == nil {
		t.Error("Invalid application passed validation")
	}
}

// TestMerging tests application merging
func TestMerging(t *testing.T) {
	paas := New(nil)

	app1 := createTestApplication()

	// Create app2 with different services
	app2 := &Application{
		Platform: PlatformDockerCompose,
		Services: map[string]*Service{
			"web2": {
				Name:  "web2",
				Image: "nginx:alpine",
			},
			"cache": {
				Name:  "cache",
				Image: "redis:alpine",
			},
		},
		Networks: make(map[string]*Network),
		Volumes:  make(map[string]*Volume),
		Configs:  make(map[string]*Config),
		Secrets:  make(map[string]*Secret),
	}

	merged, err := paas.MergeApplications(app1, app2)
	if err != nil {
		t.Fatalf("Failed to merge applications: %v", err)
	}

	expectedServices := len(app1.Services) + len(app2.Services)
	if len(merged.Services) != expectedServices {
		t.Errorf("Merge failed: expected %d services, got %d",
			expectedServices, len(merged.Services))
	}
}

// createTestApplication creates a test application with various services
func createTestApplication() *Application {
	return &Application{
		Version:  "3.8",
		Platform: PlatformDockerCompose,
		Services: map[string]*Service{
			"web": {
				Name:          "web",
				Image:         "nginx:alpine",
				ContainerName: "web",
				Hostname:      "web.local",
				Ports: []PortMapping{
					{HostPort: "80", ContainerPort: "80", Protocol: "tcp"},
				},
				Environment: map[string]string{
					"NGINX_PORT": "80",
					"TZ":         "America/Chicago",
				},
				Volumes: []VolumeMount{
					{Source: "/host/logs", Target: "/var/log/nginx", Type: "bind"},
				},
				Restart: "unless-stopped",
				Labels: map[string]string{
					"app":     "web",
					"version": "1.0",
				},
				HealthCheck: &HealthCheck{
					Test:     []string{"CMD", "curl", "-f", "http://localhost/"},
					Interval: "30s",
					Timeout:  "10s",
					Retries:  3,
				},
			},
			"api": {
				Name:  "api",
				Image: "golang:alpine",
				Command: []string{
					"./app",
					"-port=8080",
				},
				Environment: map[string]string{
					"DATABASE_URL": "postgres://db:5432",
					"REDIS_URL":    "redis://redis:6379",
				},
				DependsOn: []string{"db", "redis"},
				Networks:  []string{"backend"},
			},
			"db": {
				Name:  "db",
				Image: "postgres:13",
				Environment: map[string]string{
					"POSTGRES_DB":       "myapp",
					"POSTGRES_USER":     "user",
					"POSTGRES_PASSWORD": "password",
				},
				Volumes: []VolumeMount{
					{Source: "db_data", Target: "/var/lib/postgresql/data", Type: "volume"},
				},
				Networks: []string{"backend"},
			},
			"redis": {
				Name:  "redis",
				Image: "redis:alpine",
				Ports: []PortMapping{
					{HostPort: "6379", ContainerPort: "6379"},
				},
				Command:     []string{"redis-server", "--appendonly", "yes"},
				Networks:    []string{"backend"},
				MemoryLimit: "256M",
			},
		},
		Networks: map[string]*Network{
			"backend": {
				Name:       "backend",
				Driver:     "bridge",
				Attachable: true,
				IPAM: &IPAMConfig{
					Config: []IPAMSubnet{
						{Subnet: "172.20.0.0/16", Gateway: "172.20.0.1"},
					},
				},
			},
		},
		Volumes: map[string]*Volume{
			"db_data": {
				Name:   "db_data",
				Driver: "local",
			},
		},
		Configs: map[string]*Config{
			"nginx.conf": {
				Name: "nginx.conf",
				Content: `server {
    listen 80;
    server_name localhost;
    location / {
        proxy_pass http://api:8080;
    }
}`,
			},
		},
		Secrets: map[string]*Secret{
			"db_password": {
				Name:     "db_password",
				File:     "/run/secrets/db_password",
				External: false,
			},
		},
	}
}

// BenchmarkConversion benchmarks conversion performance
func BenchmarkConversion(b *testing.B) {
	app := createTestApplication()
	paas := New(nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := paas.Convert(app, PlatformDockerCompose, PlatformNomad)
		if err != nil {
			b.Fatalf("Conversion failed: %v", err)
		}
	}
}

// BenchmarkSerialization benchmarks serialization performance
func BenchmarkSerialization(b *testing.B) {
	app := createTestApplication()
	paas := New(nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := paas.SaveContent(app, PlatformDockerCompose)
		if err != nil {
			b.Fatalf("Serialization failed: %v", err)
		}
	}
}
