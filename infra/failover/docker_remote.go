package failover

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
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

// TransferVolumes transfers volume data from source to target node
// This is a simplified implementation - in production, you'd use rsync, tar over SSH, or a distributed storage system
func TransferVolumes(ctx context.Context, sourceCli *client.Client, targetCli *client.Client, containerID string, volumes []mount.Mount) error {
	// For each volume mount, we need to:
	// 1. Export data from source container
	// 2. Transfer to target node
	// 3. Import into target container

	// This is a complex operation that requires:
	// - Volume export (docker cp or tar)
	// - Network transfer (via Tailscale)
	// - Volume import on target

	// For now, we'll log what needs to be done
	// In production, implement:
	// - Use docker cp to export volumes
	// - Transfer via Tailscale network (rsync, scp, or direct TCP)
	// - Import on target node

	log.Printf("Volume transfer required for %d volumes (implementation needed)", len(volumes))
	for _, vol := range volumes {
		log.Printf("  Volume: %s -> %s (type: %s)", vol.Source, vol.Target, vol.Type)
	}

	// TODO: Implement actual volume transfer
	// This would involve:
	// 1. Creating a tar archive of volume data on source
	// 2. Transferring tar over Tailscale network
	// 3. Extracting tar on target node
	// 4. Ensuring proper permissions and ownership

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
