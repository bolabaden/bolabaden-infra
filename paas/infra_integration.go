package paas

import (
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// InfraIntegration provides integration with the existing infra codebase
type InfraIntegration struct {
	InfraPath string // Path to the infra directory
}

// NewInfraIntegration creates a new infra integration instance
func NewInfraIntegration(infraPath string) *InfraIntegration {
	return &InfraIntegration{
		InfraPath: infraPath,
	}
}

// DeployToInfra converts an Application to infra Go code and writes service files
func (ii *InfraIntegration) DeployToInfra(app *Application, servicesDir string) error {
	servicesPath := filepath.Join(ii.InfraPath, servicesDir)
	if err := os.MkdirAll(servicesPath, 0755); err != nil {
		return fmt.Errorf("failed to create services directory: %w", err)
	}

	// Generate service files
	for name, service := range app.Services {
		filename := fmt.Sprintf("services_%s.go", strings.ToLower(name))
		filepath := filepath.Join(servicesPath, filename)

		code, err := ii.generateInfraService(name, service)
		if err != nil {
			return fmt.Errorf("failed to generate service code for %s: %w", name, err)
		}

		if err := os.WriteFile(filepath, []byte(code), 0644); err != nil {
			return fmt.Errorf("failed to write service file %s: %w", filepath, err)
		}

		fmt.Printf("Generated %s\n", filepath)
	}

	// Update main services.go to include new services
	if err := ii.updateMainServicesFile(app); err != nil {
		return fmt.Errorf("failed to update main services file: %w", err)
	}

	return nil
}

// generateInfraService generates Go code for a service in infra format
func (ii *InfraIntegration) generateInfraService(name string, service *Service) (string, error) {
	var sb strings.Builder

	sb.WriteString("package main\n\n")
	sb.WriteString("import (\n")
	sb.WriteString("\t\"fmt\"\n")
	sb.WriteString("\t\"github.com/docker/docker/api/types/mount\"\n")
	sb.WriteString(")\n\n")

	sb.WriteString(fmt.Sprintf("// %sService returns the %s service configuration\n", strings.Title(name), name))
	sb.WriteString(fmt.Sprintf("func %sService(configPath, secretsPath, domain, tsHostname string) Service {\n", strings.Title(name)))

	// Basic service fields
	sb.WriteString(fmt.Sprintf("\treturn Service{\n"))
	sb.WriteString(fmt.Sprintf("\t\tName:          \"%s\",\n", name))
	sb.WriteString(fmt.Sprintf("\t\tImage:         \"%s\",\n", service.Image))

	if service.ContainerName != "" {
		sb.WriteString(fmt.Sprintf("\t\tContainerName: \"%s\",\n", service.ContainerName))
	}

	if service.Hostname != "" {
		sb.WriteString(fmt.Sprintf("\t\tHostname:      \"%s\",\n", service.Hostname))
	}

	// Ports
	if len(service.Ports) > 0 {
		sb.WriteString("\t\tPorts: []PortMapping{\n")
		for _, port := range service.Ports {
			sb.WriteString(fmt.Sprintf("\t\t\t{HostIP: \"%s\", HostPort: \"%s\", ContainerPort: \"%s\", Protocol: \"%s\"},\n",
				port.HostIP, port.HostPort, port.ContainerPort, port.Protocol))
		}
		sb.WriteString("\t\t},\n")
	}

	// Environment variables
	if len(service.Environment) > 0 {
		sb.WriteString("\t\tEnvironment: map[string]string{\n")
		for key, value := range service.Environment {
			sb.WriteString(fmt.Sprintf("\t\t\t\"%s\": \"%s\",\n", key, value))
		}
		sb.WriteString("\t\t},\n")
	}

	// Volumes
	if len(service.Volumes) > 0 {
		sb.WriteString("\t\tVolumes: []VolumeMount{\n")
		for _, vol := range service.Volumes {
			sb.WriteString(fmt.Sprintf("\t\t\t{Source: \"%s\", Target: \"%s\", Type: \"%s\", ReadOnly: %t},\n",
				vol.Source, vol.Target, vol.Type, vol.ReadOnly))
		}
		sb.WriteString("\t\t},\n")
	}

	// Networks
	if len(service.Networks) > 0 {
		sb.WriteString(fmt.Sprintf("\t\tNetworks:      []string{%s},\n",
			ii.formatStringSlice(service.Networks)))
	}

	// Restart policy
	if service.Restart != "" {
		sb.WriteString(fmt.Sprintf("\t\tRestart:       \"%s\",\n", service.Restart))
	}

	// Labels
	if len(service.Labels) > 0 {
		sb.WriteString("\t\tLabels: map[string]string{\n")
		for key, value := range service.Labels {
			sb.WriteString(fmt.Sprintf("\t\t\t\"%s\": \"%s\",\n", key, value))
		}
		sb.WriteString("\t\t},\n")
	}

	sb.WriteString("\t}\n")
	sb.WriteString("}\n")

	return sb.String(), nil
}

// updateMainServicesFile updates the main services.go file to include new services
func (ii *InfraIntegration) updateMainServicesFile(app *Application) error {
	mainServicesFile := filepath.Join(ii.InfraPath, "services.go")

	// Read existing file
	content, err := os.ReadFile(mainServicesFile)
	if err != nil {
		return fmt.Errorf("failed to read main services file: %w", err)
	}

	// Parse the Go file
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, "", content, parser.ParseComments)
	if err != nil {
		return fmt.Errorf("failed to parse Go file: %w", err)
	}

	// Find the defineServices function
	var defineServicesFunc *ast.FuncDecl
	ast.Inspect(file, func(n ast.Node) bool {
		if fn, ok := n.(*ast.FuncDecl); ok && fn.Name.Name == "defineServices" {
			defineServicesFunc = fn
			return false
		}
		return true
	})

	if defineServicesFunc == nil {
		return fmt.Errorf("could not find defineServices function")
	}

	// Add new service calls to the function
	// This is a simplified approach - in practice, you'd want to be more careful
	// about AST manipulation

	newServicesCode := "\n\t// PaaS-generated services\n"
	for name := range app.Services {
		titleName := strings.Title(name)
		newServicesCode += fmt.Sprintf("\tservices = append(services, %sService(configPath, secretsPath, domain, tsHostname))\n", titleName)
	}

	// For now, just append to the end of the file
	// In a real implementation, you'd want to properly modify the AST
	newContent := string(content) + newServicesCode

	// Format the code
	formatted, err := format.Source([]byte(newContent))
	if err != nil {
		return fmt.Errorf("failed to format Go code: %w", err)
	}

	// Write back
	return os.WriteFile(mainServicesFile, formatted, 0644)
}

// LoadFromInfra loads an Application from existing infra Go files
func (ii *InfraIntegration) LoadFromInfra() (*Application, error) {
	app := &Application{
		Platform: PlatformDockerCompose, // Default to Docker Compose for infra
		Services: make(map[string]*Service),
	}

	// This is a complex task that would require parsing Go code
	// For now, return a placeholder implementation
	return app, fmt.Errorf("loading from infra Go files not yet implemented")
}

// formatStringSlice formats a string slice for Go code
func (ii *InfraIntegration) formatStringSlice(slice []string) string {
	if len(slice) == 0 {
		return ""
	}

	quoted := make([]string, len(slice))
	for i, s := range slice {
		quoted[i] = fmt.Sprintf("\"%s\"", s)
	}

	return strings.Join(quoted, ", ")
}

// ValidateInfraIntegration validates that the infra integration will work
func (ii *InfraIntegration) ValidateInfraIntegration() error {
	// Check if infra directory exists
	if _, err := os.Stat(ii.InfraPath); os.IsNotExist(err) {
		return fmt.Errorf("infra directory does not exist: %s", ii.InfraPath)
	}

	// Check if main services.go exists
	mainServicesFile := filepath.Join(ii.InfraPath, "services.go")
	if _, err := os.Stat(mainServicesFile); os.IsNotExist(err) {
		return fmt.Errorf("main services.go file does not exist: %s", mainServicesFile)
	}

	return nil
}