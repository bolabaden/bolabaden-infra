package paas

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// ParseHelmChart parses a Helm chart directory
func ParseHelmChart(chartPath string) (*Application, error) {
	// Check if it's a chart directory
	chartYaml := filepath.Join(chartPath, "Chart.yaml")
	if _, err := os.Stat(chartYaml); os.IsNotExist(err) {
		return nil, fmt.Errorf("not a Helm chart directory: %s", chartPath)
	}

	// Read Chart.yaml
	chartData, err := os.ReadFile(chartYaml)
	if err != nil {
		return nil, fmt.Errorf("failed to read Chart.yaml: %w", err)
	}

	var chartMeta map[string]interface{}
	if err := yaml.Unmarshal(chartData, &chartMeta); err != nil {
		return nil, fmt.Errorf("failed to parse Chart.yaml: %w", err)
	}

	app := &Application{
		Platform: PlatformHelm,
		Services: make(map[string]*Service),
	}

	// Parse templates directory
	templatesDir := filepath.Join(chartPath, "templates")
	if _, err := os.Stat(templatesDir); err == nil {
		err := filepath.Walk(templatesDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			if !strings.HasSuffix(path, ".yaml") && !strings.HasSuffix(path, ".yml") {
				return nil
			}

			content, err := os.ReadFile(path)
			if err != nil {
				return fmt.Errorf("failed to read template %s: %w", path, err)
			}

			// Parse as Kubernetes resources
			k8sApp, err := ParseKubernetesYAML(string(content))
			if err != nil {
				// Skip files that can't be parsed as Kubernetes resources
				return nil
			}

			// Merge into main app
			for name, service := range k8sApp.Services {
				app.Services[name] = service
			}
			for name, network := range k8sApp.Networks {
				if app.Networks == nil {
					app.Networks = make(map[string]*Network)
				}
				app.Networks[name] = network
			}
			for name, volume := range k8sApp.Volumes {
				if app.Volumes == nil {
					app.Volumes = make(map[string]*Volume)
				}
				app.Volumes[name] = volume
			}
			for name, config := range k8sApp.Configs {
				if app.Configs == nil {
					app.Configs = make(map[string]*Config)
				}
				app.Configs[name] = config
			}
			for name, secret := range k8sApp.Secrets {
				if app.Secrets == nil {
					app.Secrets = make(map[string]*Secret)
				}
				app.Secrets[name] = secret
			}

			return nil
		})

		if err != nil {
			return nil, fmt.Errorf("failed to walk templates directory: %w", err)
		}
	}

	// Store chart metadata
	if app.Extensions == nil {
		app.Extensions = make(map[string]interface{})
	}
	app.Extensions["chart"] = chartMeta

	return app, nil
}

// SerializeHelmChart generates a Helm chart from an Application
func SerializeHelmChart(app *Application, chartPath string) error {
	// Create chart directory
	if err := os.MkdirAll(chartPath, 0755); err != nil {
		return fmt.Errorf("failed to create chart directory: %w", err)
	}

	// Create Chart.yaml
	chartYaml := map[string]interface{}{
		"apiVersion": "v2",
		"name":       filepath.Base(chartPath),
		"description": fmt.Sprintf("Generated Helm chart for %s", app.Platform),
		"type":       "application",
		"version":    "0.1.0",
		"appVersion": "1.0.0",
	}

	if chartMeta, ok := app.Extensions["chart"].(map[string]interface{}); ok {
		// Merge with existing metadata
		for k, v := range chartMeta {
			chartYaml[k] = v
		}
	}

	chartData, err := yaml.Marshal(chartYaml)
	if err != nil {
		return fmt.Errorf("failed to marshal Chart.yaml: %w", err)
	}

	if err := os.WriteFile(filepath.Join(chartPath, "Chart.yaml"), chartData, 0644); err != nil {
		return fmt.Errorf("failed to write Chart.yaml: %w", err)
	}

	// Create templates directory
	templatesDir := filepath.Join(chartPath, "templates")
	if err := os.MkdirAll(templatesDir, 0755); err != nil {
		return fmt.Errorf("failed to create templates directory: %w", err)
	}

	// Generate Kubernetes YAML files
	k8sContent, err := SerializeKubernetesYAML(app)
	if err != nil {
		return fmt.Errorf("failed to serialize Kubernetes YAML: %w", err)
	}

	// Split into individual resources and create template files
	documents := strings.Split(k8sContent, "\n---\n")
	for i, doc := range documents {
		doc = strings.TrimSpace(doc)
		if doc == "" {
			continue
		}

		// Determine resource type and name
		var resourceType, resourceName string
		lines := strings.Split(doc, "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "kind: ") {
				resourceType = strings.TrimPrefix(line, "kind: ")
			} else if strings.HasPrefix(line, "  name: ") {
				resourceName = strings.TrimPrefix(line, "  name: ")
			}
		}

		if resourceType == "" {
			resourceType = "resource"
		}
		if resourceName == "" {
			resourceName = fmt.Sprintf("%d", i)
		}

		filename := fmt.Sprintf("%s-%s.yaml", strings.ToLower(resourceType), resourceName)
		filepath := filepath.Join(templatesDir, filename)

		if err := os.WriteFile(filepath, []byte(doc), 0644); err != nil {
			return fmt.Errorf("failed to write template %s: %w", filename, err)
		}
	}

	return nil
}