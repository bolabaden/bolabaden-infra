package failover

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/api/types/mount"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

// RemoteDockerClient provides access to Docker API on remote nodes via Tailscale network
type RemoteDockerClient struct {
	host       string
	httpClient *http.Client
	apiVersion string
}

// NewRemoteDockerClient creates a client for accessing Docker API on a remote node
// host should be the Tailscale IP or hostname of the target node
// dockerPort is typically 2375 for unencrypted or 2376 for TLS
func NewRemoteDockerClient(host string, dockerPort int, useTLS bool) (*RemoteDockerClient, error) {
	scheme := "http"
	if useTLS {
		scheme = "https"
	}

	// Default to port 2375 if not specified
	if dockerPort == 0 {
		dockerPort = 2375
	}

	httpClient := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   10 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
		},
	}

	return &RemoteDockerClient{
		host:       fmt.Sprintf("%s://%s:%d", scheme, host, dockerPort),
		httpClient: httpClient,
		apiVersion: "1.44",
	}, nil
}

// CreateClient creates a Docker client for the remote host
func (rdc *RemoteDockerClient) CreateClient(ctx context.Context) (*client.Client, error) {
	// Create client with custom HTTP client pointing to remote Docker daemon
	cli, err := client.NewClientWithOpts(
		client.WithHost(rdc.host),
		client.WithHTTPClient(rdc.httpClient),
		client.WithVersion(rdc.apiVersion),
		client.WithAPIVersionNegotiation(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create remote Docker client: %w", err)
	}

	// Test connection
	_, err = cli.Ping(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to ping remote Docker daemon: %w", err)
	}

	return cli, nil
}

// ContainerConfig holds the configuration needed to recreate a container
type ContainerConfig struct {
	Name          string
	Image         string
	Command       []string
	Env           []string
	ExposedPorts  nat.PortSet
	PortBindings  nat.PortMap
	Mounts        []mount.Mount
	Networks      []string
	Labels        map[string]string
	RestartPolicy container.RestartPolicy
	Healthcheck   *container.HealthConfig
	Resources     container.Resources
}

// ExportContainerConfig extracts container configuration for migration
func ExportContainerConfig(ctx context.Context, cli *client.Client, containerID string) (*ContainerConfig, error) {
	inspect, err := cli.ContainerInspect(ctx, containerID)
	if err != nil {
		return nil, fmt.Errorf("failed to inspect container: %w", err)
	}

	// Convert types.MountPoint to mount.Mount
	// types.MountPoint is a read-only view from ContainerInspect, so we extract basic info
	mounts := make([]mount.Mount, 0, len(inspect.Mounts))
	for _, mp := range inspect.Mounts {
		mounts = append(mounts, mount.Mount{
			Type:     mount.Type(mp.Type),
			Source:   mp.Source,
			Target:   mp.Destination,
			ReadOnly: !mp.RW,
			// Note: MountPoint from inspect doesn't include BindOptions/VolumeOptions/TmpfsOptions
			// These would need to be preserved from the original container creation config
		})
	}

	config := &ContainerConfig{
		Name:         inspect.Name,
		Image:        inspect.Config.Image,
		Command:      inspect.Config.Cmd,
		Env:          inspect.Config.Env,
		ExposedPorts: inspect.Config.ExposedPorts,
		PortBindings: inspect.HostConfig.PortBindings,
		Mounts:       mounts,
		Labels:       inspect.Config.Labels,
		RestartPolicy: container.RestartPolicy{
			Name:              inspect.HostConfig.RestartPolicy.Name,
			MaximumRetryCount: inspect.HostConfig.RestartPolicy.MaximumRetryCount,
		},
		Healthcheck: inspect.Config.Healthcheck,
		Resources: container.Resources{
			Memory:    inspect.HostConfig.Memory,
			CPUShares: inspect.HostConfig.CPUShares,
			CPUQuota:  inspect.HostConfig.CPUQuota,
			CPUPeriod: inspect.HostConfig.CPUPeriod,
		},
	}

	// Extract network names
	for netName := range inspect.NetworkSettings.Networks {
		config.Networks = append(config.Networks, netName)
	}

	return config, nil
}

// CreateContainerOnRemote creates a container on a remote node with the given configuration
func CreateContainerOnRemote(ctx context.Context, remoteCli *client.Client, config *ContainerConfig) (string, error) {
	// Create container configuration
	containerConfig := &container.Config{
		Image:        config.Image,
		Cmd:          config.Command,
		Env:          config.Env,
		ExposedPorts: config.ExposedPorts,
		Labels:       config.Labels,
		Healthcheck:  config.Healthcheck,
	}

	hostConfig := &container.HostConfig{
		PortBindings: config.PortBindings,
		Mounts:       config.Mounts,
		RestartPolicy: container.RestartPolicy{
			Name:              config.RestartPolicy.Name,
			MaximumRetryCount: config.RestartPolicy.MaximumRetryCount,
		},
		Resources: config.Resources,
	}

	// Create network configuration
	networkingConfig := &network.NetworkingConfig{
		EndpointsConfig: make(map[string]*network.EndpointSettings),
	}
	for _, netName := range config.Networks {
		networkingConfig.EndpointsConfig[netName] = &network.EndpointSettings{}
	}

	// Create the container
	createResp, err := remoteCli.ContainerCreate(ctx, containerConfig, hostConfig, networkingConfig, nil, config.Name)
	if err != nil {
		return "", fmt.Errorf("failed to create container on remote node: %w", err)
	}

	return createResp.ID, nil
}

// TransferVolumes transfers volume data from source to target node via Tailscale network
// Uses docker cp to export volumes, transfers via tar over HTTP, and extracts on target
func TransferVolumes(ctx context.Context, sourceCli *client.Client, targetCli *client.Client, containerID string, volumes []mount.Mount) error {
	if len(volumes) == 0 {
		return nil
	}

	log.Printf("Transferring %d volume(s) from source to target node", len(volumes))

	for _, vol := range volumes {
		// Skip volumes that don't need transfer (named volumes, tmpfs, etc.)
		if vol.Type != mount.TypeBind && vol.Type != mount.TypeVolume {
			log.Printf("Skipping volume %s (type: %s, not transferable)", vol.Target, vol.Type)
			continue
		}

		// For bind mounts, we need to transfer the host path
		// For named volumes, we need to copy from container
		if vol.Type == mount.TypeBind {
			if vol.Source == "" {
				log.Printf("Warning: Bind mount %s has no source, skipping", vol.Target)
				continue
			}

			// Transfer bind mount directory
			if err := transferBindMount(ctx, sourceCli, targetCli, containerID, vol); err != nil {
				return fmt.Errorf("failed to transfer bind mount %s: %w", vol.Target, err)
			}
		} else if vol.Type == mount.TypeVolume {
			// Transfer named volume data from container
			if err := transferContainerVolume(ctx, sourceCli, targetCli, containerID, vol); err != nil {
				return fmt.Errorf("failed to transfer volume %s: %w", vol.Target, err)
			}
		}
	}

	log.Printf("Successfully transferred all volumes")
	return nil
}

// transferBindMount transfers a bind mount directory from source to target node
func transferBindMount(ctx context.Context, sourceCli *client.Client, targetCli *client.Client, containerID string, vol mount.Mount) error {
	log.Printf("Transferring bind mount: %s -> %s", vol.Source, vol.Target)

	// Create tar archive of source directory
	// CopyFromContainer returns (io.ReadCloser, types.ContainerPathStat, error)
	tarReader, stat, err := sourceCli.CopyFromContainer(ctx, containerID, vol.Source)
	if err != nil {
		// If CopyFromContainer fails (e.g., path doesn't exist in container), try direct host path
		return transferHostPath(ctx, vol.Source, vol.Target, targetCli)
	}
	_ = stat // Stat information available but not needed for transfer
	defer tarReader.Close()

	// Transfer tar to target node and extract
	return extractTarToTarget(ctx, tarReader, vol.Target, targetCli, containerID)
}

// transferContainerVolume transfers volume data from container to target node
func transferContainerVolume(ctx context.Context, sourceCli *client.Client, targetCli *client.Client, containerID string, vol mount.Mount) error {
	log.Printf("Transferring container volume: %s", vol.Target)

	// Copy volume data from container
	// CopyFromContainer returns (io.ReadCloser, types.ContainerPathStat, error)
	tarReader, stat, err := sourceCli.CopyFromContainer(ctx, containerID, vol.Target)
	if err != nil {
		return fmt.Errorf("failed to copy volume from container: %w", err)
	}
	_ = stat // Stat information available but not needed for transfer
	defer tarReader.Close()

	// Transfer and extract on target
	return extractTarToTarget(ctx, tarReader, vol.Target, targetCli, containerID)
}

// transferHostPath transfers a host path directly using tar over network
// This is used when CopyFromContainer fails (e.g., path is on host, not in container)
func transferHostPath(ctx context.Context, sourcePath, targetPath string, targetCli *client.Client) error {
	// For bind mounts, the source path is on the host filesystem
	// We need to create a tar archive and transfer it
	// This requires access to the host filesystem, which may not be available in all scenarios
	// In production, bind mounts are typically shared storage or should be recreated on target
	
	// Check if source path exists
	if _, err := os.Stat(sourcePath); os.IsNotExist(err) {
		return fmt.Errorf("source path does not exist: %s", sourcePath)
	}

	// Create tar archive of source path
	cmd := exec.CommandContext(ctx, "tar", "-czf", "-", "-C", filepath.Dir(sourcePath), filepath.Base(sourcePath))
	tarOutput, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to create tar pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start tar: %w", err)
	}
	defer cmd.Wait()

	// For bind mounts on host filesystem, we need to transfer to target host
	// Bind mounts reference host filesystem paths which are not accessible via Docker API alone
	// This requires either:
	// 1. Shared storage (NFS, CIFS, etc.) where both nodes can access the same path
	// 2. SSH access to target node for direct file transfer
	// 3. A temporary container that can access the host path and transfer via Docker API
	// 
	// For production use, bind mounts should typically use shared storage or be recreated on target.
	// If SSH is available, we could implement rsync/scp transfer here.
	log.Printf("Bind mount transfer for host path %s requires shared storage, SSH access, or manual setup", sourcePath)
	_ = tarOutput // tarOutput available but requires SSH or shared storage infrastructure for transfer
	return fmt.Errorf("bind mount transfer from host path %s requires shared storage or SSH access to target node", sourcePath)
}

// extractTarToTarget extracts tar archive to target container
func extractTarToTarget(ctx context.Context, tarReader io.Reader, targetPath string, targetCli *client.Client, containerID string) error {
	// Create a temporary file to store tar data
	tmpFile, err := os.CreateTemp("", "volume-transfer-*.tar")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	// Write tar data to temp file
	if _, err := io.Copy(tmpFile, tarReader); err != nil {
		return fmt.Errorf("failed to write tar data: %w", err)
	}

	// Close file before copying
	tmpFile.Close()

	// Copy tar file into target container
	tarFile, err := os.Open(tmpFile.Name())
	if err != nil {
		return fmt.Errorf("failed to reopen temp file: %w", err)
	}
	defer tarFile.Close()

	// Use docker cp to copy tar into container
	// We need to copy to a temp location first, then extract
	copyOpts := types.CopyToContainerOptions{
		AllowOverwriteDirWithFile: true,
	}

	// Copy tar to /tmp in container
	tarPathInContainer := "/tmp/volume-transfer.tar"
	if err := targetCli.CopyToContainer(ctx, containerID, tarPathInContainer, tarFile, copyOpts); err != nil {
		return fmt.Errorf("failed to copy tar to container: %w", err)
	}

	// Extract tar in container using docker exec
	extractCmd := []string{"tar", "-xzf", tarPathInContainer, "-C", filepath.Dir(targetPath), "--strip-components=0"}
	execConfig := types.ExecConfig{
		Cmd:          extractCmd,
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := targetCli.ContainerExecCreate(ctx, containerID, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create exec: %w", err)
	}

	attachResp, err := targetCli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("failed to attach to exec: %w", err)
	}
	defer attachResp.Close()

	// Wait for extraction to complete
	inspectResp, err := targetCli.ContainerExecInspect(ctx, execResp.ID)
	if err != nil {
		return fmt.Errorf("failed to inspect exec: %w", err)
	}

	if inspectResp.ExitCode != 0 {
		// Read error output
		output, _ := io.ReadAll(attachResp.Reader)
		return fmt.Errorf("tar extraction failed (exit code %d): %s", inspectResp.ExitCode, string(output))
	}

	// Clean up temp tar file in container
	cleanupCmd := []string{"rm", "-f", tarPathInContainer}
	cleanupExecConfig := types.ExecConfig{
		Cmd: cleanupCmd,
	}
	cleanupExecResp, err := targetCli.ContainerExecCreate(ctx, containerID, cleanupExecConfig)
	if err == nil {
		targetCli.ContainerExecAttach(ctx, cleanupExecResp.ID, types.ExecStartCheck{})
	}

	log.Printf("Successfully extracted volume data to %s in target container", targetPath)
	return nil
}

// VerifyContainerHealth verifies that a container is healthy on the target node
func VerifyContainerHealth(ctx context.Context, cli *client.Client, containerID string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for time.Now().Before(deadline) {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			inspect, err := cli.ContainerInspect(ctx, containerID)
			if err != nil {
				return fmt.Errorf("failed to inspect container: %w", err)
			}

			// Check if container is running
			if !inspect.State.Running {
				return fmt.Errorf("container is not running (state: %s)", inspect.State.Status)
			}

			// Check health status if healthcheck is configured
			if inspect.Config.Healthcheck != nil {
				if inspect.State.Health != nil {
					if inspect.State.Health.Status == "healthy" {
						return nil // Container is healthy
					}
					if inspect.State.Health.Status == "unhealthy" {
						return fmt.Errorf("container health check reports unhealthy")
					}
					// Status is "starting" or "none", continue waiting
				}
			} else {
				// No healthcheck configured, consider running as healthy
				if inspect.State.Running {
					return nil
				}
			}
		}
	}

	return fmt.Errorf("container health verification timeout after %v", timeout)
}

// ExportContainerImage exports container image to a tar stream
func ExportContainerImage(ctx context.Context, cli *client.Client, imageName string) (io.ReadCloser, error) {
	// Get image
	images, err := cli.ImageList(ctx, types.ImageListOptions{
		Filters: filters.NewArgs(filters.Arg("reference", imageName)),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to list images: %w", err)
	}

	if len(images) == 0 {
		return nil, fmt.Errorf("image %s not found", imageName)
	}

	// Save image as tar
	imageReader, err := cli.ImageSave(ctx, []string{imageName})
	if err != nil {
		return nil, fmt.Errorf("failed to save image: %w", err)
	}

	return imageReader, nil
}

// LoadContainerImage loads a container image from a tar stream
func LoadContainerImage(ctx context.Context, cli *client.Client, imageReader io.Reader) error {
	_, err := cli.ImageLoad(ctx, imageReader, false)
	if err != nil {
		return fmt.Errorf("failed to load image: %w", err)
	}

	return nil
}
