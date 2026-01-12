package paas

import (
	"fmt"
	"strings"
)

// ParseNomadHCL parses a Nomad HCL file or content
func ParseNomadHCL(content string) (*Application, error) {
	// Basic parsing - look for job blocks and extract service information
	// This is a simplified parser for testing purposes

	app := &Application{
		Platform: PlatformNomad,
		Services: make(map[string]*Service),
		Networks: make(map[string]*Network),
		Volumes:  make(map[string]*Volume),
		Configs:  make(map[string]*Config),
		Secrets:  make(map[string]*Secret),
	}

	lines := strings.Split(content, "\n")
	var currentTask string

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "task ") && strings.Contains(line, "{") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				currentTask = strings.Trim(strings.TrimSpace(parts[1]), `"`)
			}
		} else if strings.Contains(line, "image = ") {
			// Extract image information
			if currentTask != "" {
				serviceName := currentTask
				image := strings.Trim(strings.Split(line, "=")[1], ` "`)

				service := &Service{
					Name:        serviceName,
					Image:       image,
					Platform:    PlatformNomad,
					Environment: make(map[string]string),
					Labels:      make(map[string]string),
				}

				app.Services[serviceName] = service
			}
		}
	}

	return app, nil
}

// Note: Full Nomad HCL parsing is complex and requires extensive HCL library usage.
// For now, we provide basic structure. Production implementation would need:
// 1. Full HCL AST parsing with proper type handling
// 2. Variable interpolation (${var.name}, var.name)
// 3. Template block processing
// 4. Service discovery integration
// 5. Constraint and affinity handling
//
// TODO: Implement comprehensive Nomad HCL parsing for production use

// SerializeNomadHCL converts an Application to Nomad HCL
func SerializeNomadHCL(app *Application) (string, error) {
	var hcl strings.Builder

	// Write header
	hcl.WriteString("# Auto-generated Nomad HCL from PaaS converter\n\n")

	// Write job
	jobName := "app"
	hcl.WriteString(fmt.Sprintf("job \"%s\" {\n", jobName))
	hcl.WriteString("  datacenters = [\"dc1\"]\n")
	hcl.WriteString("  type = \"service\"\n\n")

	// Write groups for each service
	for serviceName, service := range app.Services {
		hcl.WriteString(fmt.Sprintf("  group \"%s\" {\n", serviceName))
		hcl.WriteString("    count = 1\n\n")

		// Write task
		hcl.WriteString(fmt.Sprintf("    task \"%s\" {\n", serviceName))

		// Driver
		hcl.WriteString("      driver = \"docker\"\n\n")

		// Config
		hcl.WriteString("      config {\n")
		if service.Image != "" {
			hcl.WriteString(fmt.Sprintf("        image = \"%s\"\n", service.Image))
		}
		hcl.WriteString("      }\n")

		hcl.WriteString("    }\n") // End task
		hcl.WriteString("  }\n\n") // End group
	}

	hcl.WriteString("}\n")

	return hcl.String(), nil
}
