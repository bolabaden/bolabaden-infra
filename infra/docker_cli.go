package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"
	"github.com/docker/go-units"
)

// DockerCLI provides Docker CLI compatibility for the infra system
type DockerCLI struct {
	config *Config
	docker *client.Client
}

// NewDockerCLI creates a new Docker CLI compatibility layer
func NewDockerCLI(config *Config) (*DockerCLI, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		return nil, fmt.Errorf("failed to create docker client: %w", err)
	}

	return &DockerCLI{
		config: config,
		docker: cli,
	}, nil
}

// ExecuteDockerCommand executes a Docker CLI command
func (d *DockerCLI) ExecuteDockerCommand(args []string) error {
	if len(args) == 0 {
		return d.showHelp()
	}

	// Check if this is a compose command
	if args[0] == "compose" || args[0] == "docker-compose" {
		return d.executeComposeCommand(args[1:])
	}

	// Handle other docker commands
	switch args[0] {
	case "ps":
		return d.executePsCommand(args[1:])
	case "logs":
		return d.executeLogsCommand(args[1:])
	case "exec":
		return d.executeExecCommand(args[1:])
	case "run":
		return d.executeRunCommand(args[1:])
	case "stop":
		return d.executeStopCommand(args[1:])
	case "rm":
		return d.executeRmCommand(args[1:])
	case "images":
		return d.executeImagesCommand(args[1:])
	case "version":
		return d.executeVersionCommand(args[1:])
	case "info":
		return d.executeInfoCommand(args[1:])
	default:
		return fmt.Errorf("unsupported docker command: %s", args[0])
	}
}

// executeComposeCommand handles docker compose commands
func (d *DockerCLI) executeComposeCommand(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("compose command requires subcommand")
	}

	subcommand := args[0]
	composeArgs := args[1:]

	switch subcommand {
	case "up":
		return d.executeComposeUp(composeArgs)
	case "down":
		return d.executeComposeDown(composeArgs)
	case "ps":
		return d.executeComposePs(composeArgs)
	case "logs":
		return d.executeComposeLogs(composeArgs)
	case "exec":
		return d.executeComposeExec(composeArgs)
	case "run":
		return d.executeComposeRun(composeArgs)
	case "pull":
		return d.executeComposePull(composeArgs)
	case "build":
		return d.executeComposeBuild(composeArgs)
	case "config":
		return d.executeComposeConfig(composeArgs)
	default:
		return fmt.Errorf("unsupported compose subcommand: %s", subcommand)
	}
}

// executeComposeUp handles docker compose up command
func (d *DockerCLI) executeComposeUp(args []string) error {
	// Parse compose up arguments
	var detach bool
	var removeOrphans bool
	var forceRecreate bool
	var build bool
	var pull string
	var services []string

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-d", "--detach":
			detach = true
		case "--remove-orphans":
			removeOrphans = true
		case "--force-recreate":
			forceRecreate = true
		case "--build":
			build = true
		case "--pull":
			if i+1 < len(args) {
				pull = args[i+1]
				i++
			}
		case "--help", "-h":
			return d.showComposeUpHelp()
		default:
			if !strings.HasPrefix(arg, "-") {
				services = append(services, arg)
			}
		}
	}

	// Find compose file
	composeFile := d.findComposeFile()
	if composeFile == "" {
		return fmt.Errorf("no docker-compose.yml file found")
	}

	log.Printf("Deploying from %s", composeFile)

	// Use the PaaS system to parse and deploy
	return d.deployFromComposeFile(composeFile, services, detach, removeOrphans, forceRecreate, build, pull)
}

// executeComposeDown handles docker compose down command
func (d *DockerCLI) executeComposeDown(args []string) error {
	var removeOrphans bool
	var volumes bool
	var timeout int

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--remove-orphans":
			removeOrphans = true
		case "--volumes", "-v":
			volumes = true
		case "--timeout":
			if i+1 < len(args) {
				if t, err := parseComposeInt(args[i+1]); err == nil {
					timeout = t
				}
				i++
			}
		}
	}

	// Find compose file
	composeFile := d.findComposeFile()
	if composeFile == "" {
		return fmt.Errorf("no docker-compose.yml file found")
	}

	log.Printf("Stopping services from %s", composeFile)

	// Stop services
	return d.stopFromComposeFile(composeFile, removeOrphans, volumes, timeout)
}

// executeComposePs handles docker compose ps command
func (d *DockerCLI) executeComposePs(args []string) error {
	var all bool
	var services []string

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-a", "--all":
			all = true
		default:
			if !strings.HasPrefix(arg, "-") {
				services = append(services, arg)
			}
		}
	}

	return d.listServicesFromCompose(services, all)
}

// executeComposeLogs handles docker compose logs command
func (d *DockerCLI) executeComposeLogs(args []string) error {
	var follow bool
	var tail int
	var services []string

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-f", "--follow":
			follow = true
		case "--tail":
			if i+1 < len(args) {
				if t, err := parseComposeInt(args[i+1]); err == nil {
					tail = t
				}
				i++
			}
		default:
			if !strings.HasPrefix(arg, "-") {
				services = append(services, arg)
			}
		}
	}

	return d.showLogsFromCompose(services, follow, tail)
}

// findComposeFile finds the docker-compose.yml file
func (d *DockerCLI) findComposeFile() string {
	// Check current directory first
	if _, err := os.Stat("docker-compose.yml"); err == nil {
		return "docker-compose.yml"
	}
	if _, err := os.Stat("docker-compose.yaml"); err == nil {
		return "docker-compose.yaml"
	}

	// Check for compose override files
	if _, err := os.Stat("docker-compose.override.yml"); err == nil {
		return "docker-compose.override.yml"
	}
	if _, err := os.Stat("docker-compose.override.yaml"); err == nil {
		return "docker-compose.override.yaml"
	}

	return ""
}

// deployFromComposeFile deploys services from a compose file
func (d *DockerCLI) deployFromComposeFile(composeFile string, services []string, detach, removeOrphans, forceRecreate, build bool, pull string) error {
	log.Printf("Deploying services from %s with options: detach=%v, removeOrphans=%v, forceRecreate=%v, build=%v, pull=%s",
		composeFile, detach, removeOrphans, forceRecreate, build, pull)

	// Create infrastructure manager
	infra, err := NewInfrastructure(d.config)
	if err != nil {
		return fmt.Errorf("failed to create infrastructure: %v", err)
	}
	defer infra.client.Close()

	// Ensure networks exist
	if err := infra.EnsureNetworks(); err != nil {
		return fmt.Errorf("failed to ensure networks: %v", err)
	}

	// Deploy services
	for _, svc := range d.config.Services {
		// Filter services if specific ones are requested
		if len(services) > 0 {
			found := false
			for _, requested := range services {
				if svc.Name == requested {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}

		if err := infra.DeployService(svc); err != nil {
			log.Printf("Error deploying %s: %v", svc.Name, err)
		}
	}

	if !detach {
		// Wait for services to be ready
		log.Println("Services deployed. Press Ctrl+C to stop.")
		// In a real implementation, we'd wait for user input or service completion
		time.Sleep(1 * time.Second)
	}

	return nil
}

// stopFromComposeFile stops services from a compose file
func (d *DockerCLI) stopFromComposeFile(composeFile string, removeOrphans, volumes bool, timeout int) error {
	log.Printf("Stopping services from %s with options: removeOrphans=%v, volumes=%v, timeout=%d",
		composeFile, removeOrphans, volumes, timeout)

	// Create infrastructure manager
	infra, err := NewInfrastructure(d.config)
	if err != nil {
		return fmt.Errorf("failed to create infrastructure: %v", err)
	}
	defer infra.client.Close()

	// Stop services by finding and stopping containers
	ctx := context.Background()
	for _, svc := range d.config.Services {
		containers, err := infra.client.ContainerList(ctx, types.ContainerListOptions{
			All:     true,
			Filters: filters.NewArgs(filters.Arg("name", svc.ContainerName)),
		})
		if err != nil {
			log.Printf("Error listing containers for %s: %v", svc.Name, err)
			continue
		}

		for _, c := range containers {
			stopTimeoutSeconds := timeout
			if stopTimeoutSeconds == 0 {
				stopTimeoutSeconds = 10
			}
			if err := infra.client.ContainerStop(ctx, c.ID, container.StopOptions{Timeout: &stopTimeoutSeconds}); err != nil {
				log.Printf("Error stopping container %s: %v", c.ID, err)
			}
		}
	}

	return nil
}

// listServicesFromCompose lists services from compose
func (d *DockerCLI) listServicesFromCompose(services []string, all bool) error {
	containers, err := d.docker.ContainerList(context.Background(), types.ContainerListOptions{
		All: all,
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	fmt.Printf("NAME\t\tIMAGE\t\tSTATUS\t\tPORTS\n")
	for _, container := range containers {
		// Filter by services if specified
		if len(services) > 0 {
			serviceName := d.getServiceNameFromContainer(container)
			if !contains(services, serviceName) {
				continue
			}
		}

		name := strings.TrimPrefix(container.Names[0], "/")
		image := container.Image
		status := container.Status
		ports := d.formatPorts(container.Ports)

		fmt.Printf("%s\t\t%s\t\t%s\t\t%s\n", name, image, status, ports)
	}

	return nil
}

// showLogsFromCompose shows logs from compose services
func (d *DockerCLI) showLogsFromCompose(services []string, follow bool, tail int) error {
	containers, err := d.docker.ContainerList(context.Background(), types.ContainerListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	for _, container := range containers {
		serviceName := d.getServiceNameFromContainer(container)
		if len(services) > 0 && !contains(services, serviceName) {
			continue
		}

		fmt.Printf("Logs for %s (%s):\n", serviceName, container.ID[:12])

		options := types.ContainerLogsOptions{
			ShowStdout: true,
			ShowStderr: true,
			Follow:     follow,
		}

		if tail > 0 {
			tailStr := fmt.Sprintf("%d", tail)
			options.Tail = tailStr
		}

		logs, err := d.docker.ContainerLogs(context.Background(), container.ID, options)
		if err != nil {
			log.Printf("Failed to get logs for %s: %v", container.ID, err)
			continue
		}

		io.Copy(os.Stdout, logs)
		logs.Close()
	}

	return nil
}

// Helper functions
func (d *DockerCLI) getServiceNameFromContainer(container types.Container) string {
	// Extract service name from container labels or name
	for _, name := range container.Names {
		// Remove leading slash
		cleanName := strings.TrimPrefix(name, "/")
		// If it contains underscore, it's likely service_instance format
		if strings.Contains(cleanName, "_") {
			return strings.Split(cleanName, "_")[0]
		}
	}
	return container.Names[0]
}

func (d *DockerCLI) formatPorts(ports []types.Port) string {
	var portStrings []string
	for _, port := range ports {
		if port.PublicPort != 0 {
			portStrings = append(portStrings, fmt.Sprintf("%d->%d/%s", port.PublicPort, port.PrivatePort, port.Type))
		}
	}
	return strings.Join(portStrings, ", ")
}

func (d *DockerCLI) showHelp() error {
	fmt.Println("Docker CLI compatibility layer for infra")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  docker [OPTIONS] COMMAND")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  compose     Docker Compose commands")
	fmt.Println("  ps          List containers")
	fmt.Println("  logs        Fetch the logs of a container")
	fmt.Println("  exec        Run a command in a running container")
	fmt.Println("  run         Run a command in a new container")
	fmt.Println("  stop        Stop one or more running containers")
	fmt.Println("  rm          Remove one or more containers")
	fmt.Println("  images      List images")
	fmt.Println("  version     Show the Docker version information")
	fmt.Println("  info        Display system-wide information")
	fmt.Println()
	fmt.Println("Use 'docker COMMAND --help' for more information on a command.")
	return nil
}

func (d *DockerCLI) showComposeUpHelp() error {
	fmt.Println("Start services")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  docker compose up [OPTIONS] [SERVICE...]")
	fmt.Println()
	fmt.Println("Options:")
	fmt.Println("  -d, --detach          Detached mode: Run containers in the background")
	fmt.Println("  --remove-orphans      Remove containers for services not defined in the Compose file")
	fmt.Println("  --force-recreate      Recreate containers even if their configuration and image haven't changed")
	fmt.Println("  --build               Build images before starting containers")
	fmt.Println("  --pull string         Pull image before running (\"always\"|\"missing\"|\"never\")")
	return nil
}

// executePsCommand handles docker ps command
func (d *DockerCLI) executePsCommand(args []string) error {
	var all bool
	for _, arg := range args {
		if arg == "-a" || arg == "--all" {
			all = true
		}
	}

	containers, err := d.docker.ContainerList(context.Background(), types.ContainerListOptions{
		All: all,
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	fmt.Printf("CONTAINER ID\tIMAGE\t\tCOMMAND\t\tCREATED\t\tSTATUS\t\tPORTS\t\tNAMES\n")
	for _, container := range containers {
		id := container.ID[:12]
		image := container.Image
		command := container.Command
		if len(command) > 20 {
			command = command[:17] + "..."
		}
		created := time.Unix(container.Created, 0).Format("2 hours ago")
		status := container.Status
		ports := d.formatPorts(container.Ports)
		names := strings.Join(container.Names, ",")

		fmt.Printf("%s\t%s\t\t%s\t\t%s\t\t%s\t\t%s\t\t%s\n", id, image, command, created, status, ports, names)
	}

	return nil
}

// executeLogsCommand handles docker logs command
func (d *DockerCLI) executeLogsCommand(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("container name or ID required")
	}

	container := args[0]
	var follow bool
	var tail string

	for i, arg := range args {
		if arg == "-f" || arg == "--follow" {
			follow = true
		}
		if (arg == "--tail" || arg == "-n") && i+1 < len(args) {
			tail = args[i+1]
		}
	}

	options := types.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Follow:     follow,
		Tail:       tail,
	}

	logs, err := d.docker.ContainerLogs(context.Background(), container, options)
	if err != nil {
		return fmt.Errorf("failed to get logs: %w", err)
	}
	defer logs.Close()

	_, err = io.Copy(os.Stdout, logs)
	return err
}

// executeExecCommand handles docker exec command
func (d *DockerCLI) executeExecCommand(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("container name and command required")
	}

	container := args[0]
	command := args[1:]

	execConfig := types.ExecConfig{
		Cmd:          command,
		AttachStdout: true,
		AttachStderr: true,
		AttachStdin:  true,
		Tty:          true,
	}

	id, err := d.docker.ContainerExecCreate(context.Background(), container, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create exec: %w", err)
	}

	resp, err := d.docker.ContainerExecAttach(context.Background(), id.ID, types.ExecStartCheck{
		Tty: true,
	})
	if err != nil {
		return fmt.Errorf("failed to attach exec: %w", err)
	}
	defer resp.Close()

	return nil
}

// executeRunCommand handles docker run command
func (d *DockerCLI) executeRunCommand(args []string) error {
	// This is a simplified implementation
	return fmt.Errorf("docker run not fully implemented yet")
}

// executeStopCommand handles docker stop command
func (d *DockerCLI) executeStopCommand(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("container name or ID required")
	}

	timeoutSeconds := 10
	stopOptions := container.StopOptions{Timeout: &timeoutSeconds}
	for _, containerID := range args {
		if err := d.docker.ContainerStop(context.Background(), containerID, stopOptions); err != nil {
			log.Printf("Failed to stop %s: %v", containerID, err)
		}
	}

	return nil
}

// executeRmCommand handles docker rm command
func (d *DockerCLI) executeRmCommand(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("container name or ID required")
	}

	for _, container := range args {
		if err := d.docker.ContainerRemove(context.Background(), container, types.ContainerRemoveOptions{}); err != nil {
			log.Printf("Failed to remove %s: %v", container, err)
		}
	}

	return nil
}

// executeImagesCommand handles docker images command
func (d *DockerCLI) executeImagesCommand(args []string) error {
	images, err := d.docker.ImageList(context.Background(), types.ImageListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list images: %w", err)
	}

	fmt.Printf("REPOSITORY\tTAG\t\tIMAGE ID\t\tCREATED\t\tSIZE\n")
	for _, image := range images {
		repo, tag := parseImageName(image.RepoTags)
		id := image.ID[7:19] // Remove "sha256:" prefix
		created := time.Unix(image.Created, 0).Format("2006-01-02 15:04:05")
		size := units.BytesSize(float64(image.Size))

		fmt.Printf("%s\t\t%s\t\t%s\t\t%s\t\t%s\n", repo, tag, id, created, size)
	}

	return nil
}

// executeVersionCommand handles docker version command
func (d *DockerCLI) executeVersionCommand(args []string) error {
	version, err := d.docker.ServerVersion(context.Background())
	if err != nil {
		return fmt.Errorf("failed to get version: %w", err)
	}

	fmt.Printf("Client: Infra Docker CLI compatibility layer\n")
	fmt.Printf("Server: Docker Engine - %s\n", version.Version)
	fmt.Printf("API version: %s\n", version.APIVersion)
	fmt.Printf("Go version: %s\n", version.GoVersion)
	fmt.Printf("OS/Arch: %s\n", version.Platform.Name)

	return nil
}

// executeInfoCommand handles docker info command
func (d *DockerCLI) executeInfoCommand(args []string) error {
	info, err := d.docker.Info(context.Background())
	if err != nil {
		return fmt.Errorf("failed to get info: %w", err)
	}

	fmt.Printf("Server:\n")
	fmt.Printf(" Containers: %d\n", info.Containers)
	fmt.Printf(" Images: %d\n", info.Images)
	fmt.Printf(" Storage Driver: %s\n", info.Driver)
	fmt.Printf(" OS: %s\n", info.OperatingSystem)
	fmt.Printf(" Architecture: %s\n", info.Architecture)

	return nil
}

// executeComposePull handles docker compose pull command
func (d *DockerCLI) executeComposePull(args []string) error {
	log.Printf("Pulling images for services...")
	// For now, delegate to regular docker pull
	return fmt.Errorf("compose pull not fully implemented yet")
}

// executeComposeBuild handles docker compose build command
func (d *DockerCLI) executeComposeBuild(args []string) error {
	log.Printf("Building images for services...")
	return fmt.Errorf("compose build not fully implemented yet")
}

// executeComposeConfig handles docker compose config command
func (d *DockerCLI) executeComposeConfig(args []string) error {
	composeFile := d.findComposeFile()
	if composeFile == "" {
		return fmt.Errorf("no docker-compose.yml file found")
	}

	content, err := os.ReadFile(composeFile)
	if err != nil {
		return fmt.Errorf("failed to read compose file: %w", err)
	}

	fmt.Println(string(content))
	return nil
}

// executeComposeExec handles docker compose exec command
func (d *DockerCLI) executeComposeExec(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("usage: docker compose exec SERVICE COMMAND [ARGS...]")
	}

	service := args[0]
	command := args[1:]

	// Find container for the service
	ctx := context.Background()
	containers, err := d.docker.ContainerList(ctx, types.ContainerListOptions{
		All:     true,
		Filters: filters.NewArgs(filters.Arg("label", "com.docker.compose.service="+service)),
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %w", err)
	}

	if len(containers) == 0 {
		return fmt.Errorf("no container found for service %s", service)
	}

	containerID := containers[0].ID
	execConfig := types.ExecConfig{
		Cmd:          command,
		AttachStdout: true,
		AttachStderr: true,
		AttachStdin:  true,
		Tty:          true,
	}

	id, err := d.docker.ContainerExecCreate(ctx, containerID, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create exec: %w", err)
	}

	resp, err := d.docker.ContainerExecAttach(ctx, id.ID, types.ExecStartCheck{
		Tty: true,
	})
	if err != nil {
		return fmt.Errorf("failed to attach exec: %w", err)
	}
	defer resp.Close()

	_, err = io.Copy(os.Stdout, resp.Reader)
	return err
}

// executeComposeRun handles docker compose run command
func (d *DockerCLI) executeComposeRun(args []string) error {
	// This is a simplified implementation
	// Full implementation would require parsing compose file and creating a temporary container
	return fmt.Errorf("compose run not fully implemented yet - use 'docker compose up' instead")
}

// Helper functions
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func parseComposeInt(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}

func parseImageName(repoTags []string) (string, string) {
	if len(repoTags) == 0 {
		return "<none>", "<none>"
	}

	repoTag := repoTags[0]
	if strings.Contains(repoTag, ":") {
		parts := strings.SplitN(repoTag, ":", 2)
		return parts[0], parts[1]
	}

	return repoTag, "latest"
}
