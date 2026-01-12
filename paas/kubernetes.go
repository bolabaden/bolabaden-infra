package paas

import (
	"fmt"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// ParseKubernetesYAML parses Kubernetes YAML manifests
func ParseKubernetesYAML(content string) (*Application, error) {
	// Split multi-document YAML
	documents := strings.Split(content, "\n---\n")

	app := &Application{
		Platform: PlatformKubernetes,
		Services: make(map[string]*Service),
		Networks: make(map[string]*Network),
		Volumes:  make(map[string]*Volume),
		Configs:  make(map[string]*Config),
		Secrets:  make(map[string]*Secret),
	}

	for _, doc := range documents {
		doc = strings.TrimSpace(doc)
		if doc == "" {
			continue
		}

		var resource map[string]interface{}
		if err := yaml.Unmarshal([]byte(doc), &resource); err != nil {
			continue // Skip invalid documents
		}

		if err := parseKubernetesResource(app, resource); err != nil {
			return nil, fmt.Errorf("failed to parse Kubernetes resource: %w", err)
		}
	}

	return app, nil
}

func parseKubernetesResource(app *Application, resource map[string]interface{}) error {
	kind, _ := resource["kind"].(string)

	switch kind {
	case "Deployment":
		return parseKubernetesDeployment(app, resource)
	case "Service":
		return parseKubernetesService(app, resource)
	case "ConfigMap":
		return parseKubernetesConfigMap(app, resource)
	case "Secret":
		return parseKubernetesSecret(app, resource)
	case "PersistentVolumeClaim":
		return parseKubernetesPVC(app, resource)
	case "Ingress":
		return parseKubernetesIngress(app, resource)
	}

	// Unknown resource type, skip
	return nil
}

func parseKubernetesDeployment(app *Application, resource map[string]interface{}) error {
	metadata, _ := resource["metadata"].(map[string]interface{})
	spec, _ := resource["spec"].(map[string]interface{})

	name, _ := metadata["name"].(string)
	if name == "" {
		return fmt.Errorf("deployment missing name")
	}

	template, _ := spec["template"].(map[string]interface{})
	podSpec, _ := template["spec"].(map[string]interface{})
	containers, _ := podSpec["containers"].([]interface{})

	if len(containers) == 0 {
		return fmt.Errorf("deployment %s has no containers", name)
	}

	// Use first container as main service
	container := containers[0].(map[string]interface{})

	service := &Service{
		Name:       name,
		Platform:   PlatformKubernetes,
		Environment: make(map[string]string),
		Labels:     make(map[string]string),
		Extensions: make(map[string]interface{}),
	}

	// Parse container spec
	if image, ok := container["image"].(string); ok {
		service.Image = image
	}

	if command, ok := container["command"].([]interface{}); ok {
		service.Command = interfaceSliceToStringSlice(command)
	}

	if args, ok := container["args"].([]interface{}); ok {
		if len(service.Command) == 0 {
			service.Command = interfaceSliceToStringSlice(args)
		} else {
			service.Command = append(service.Command, interfaceSliceToStringSlice(args)...)
		}
	}

	if env, ok := container["env"].([]interface{}); ok {
		for _, envVar := range env {
			if envMap, ok := envVar.(map[string]interface{}); ok {
				if name, ok := envMap["name"].(string); ok {
					if value, ok := envMap["value"].(string); ok {
						service.Environment[name] = value
					}
				}
			}
		}
	}

	if ports, ok := container["ports"].([]interface{}); ok {
		for _, port := range ports {
			if portMap, ok := port.(map[string]interface{}); ok {
				portMapping := PortMapping{}
				if containerPort, ok := portMap["containerPort"].(int); ok {
					portMapping.ContainerPort = strconv.Itoa(containerPort)
				}
				if protocol, ok := portMap["protocol"].(string); ok {
					portMapping.Protocol = strings.ToLower(protocol)
				}
				service.Ports = append(service.Ports, portMapping)
			}
		}
	}

	if volumeMounts, ok := container["volumeMounts"].([]interface{}); ok {
		for _, mount := range volumeMounts {
			if mountMap, ok := mount.(map[string]interface{}); ok {
				volumeMount := VolumeMount{}
				if name, ok := mountMap["name"].(string); ok {
					volumeMount.Source = name
				}
				if mountPath, ok := mountMap["mountPath"].(string); ok {
					volumeMount.Target = mountPath
				}
				if readOnly, ok := mountMap["readOnly"].(bool); ok {
					volumeMount.ReadOnly = readOnly
				}
				volumeMount.Type = "volume"
				service.Volumes = append(service.Volumes, volumeMount)
			}
		}
	}

	// Parse volumes at pod level
	if volumes, ok := podSpec["volumes"].([]interface{}); ok {
		for _, vol := range volumes {
			if volMap, ok := vol.(map[string]interface{}); ok {
				if name, ok := volMap["name"].(string); ok {
					volume := &Volume{Name: name}

					if configMap, ok := volMap["configMap"].(map[string]interface{}); ok {
						volume.Driver = "configMap"
						if cmName, ok := configMap["name"].(string); ok {
							volume.DriverOpts = map[string]string{"configMap": cmName}
						}
					} else if secret, ok := volMap["secret"].(map[string]interface{}); ok {
						volume.Driver = "secret"
						if secretName, ok := secret["secretName"].(string); ok {
							volume.DriverOpts = map[string]string{"secretName": secretName}
						}
					} else if hostPath, ok := volMap["hostPath"].(map[string]interface{}); ok {
						volume.Driver = "hostPath"
						if path, ok := hostPath["path"].(string); ok {
							volume.DriverOpts = map[string]string{"path": path}
						}
					}

					app.Volumes[name] = volume
				}
			}
		}
	}

	app.Services[name] = service
	return nil
}

func parseKubernetesService(app *Application, resource map[string]interface{}) error {
	metadata, _ := resource["metadata"].(map[string]interface{})
	spec, _ := resource["spec"].(map[string]interface{})

	name, _ := metadata["name"].(string)
	if name == "" {
		return fmt.Errorf("service missing name")
	}

	// Find corresponding deployment/service
	if service, exists := app.Services[name]; exists {
		if ports, ok := spec["ports"].([]interface{}); ok && len(ports) > 0 {
			for _, port := range ports {
				if portMap, ok := port.(map[string]interface{}); ok {
					if portNum, ok := portMap["port"].(int); ok {
						if targetPort, ok := portMap["targetPort"].(int); ok {
							// Update existing port mapping
							for i, p := range service.Ports {
								if p.ContainerPort == strconv.Itoa(targetPort) {
									service.Ports[i].HostPort = strconv.Itoa(portNum)
									break
								}
							}
						}
					}
				}
			}
		}
	}

	return nil
}

func parseKubernetesConfigMap(app *Application, resource map[string]interface{}) error {
	metadata, _ := resource["metadata"].(map[string]interface{})
	data, _ := resource["data"].(map[string]interface{})

	name, _ := metadata["name"].(string)
	if name == "" {
		return fmt.Errorf("configmap missing name")
	}

	config := &Config{
		Name: name,
	}

	// Convert data map to content string
	if len(data) > 0 {
		var content strings.Builder
		for key, value := range data {
			content.WriteString(fmt.Sprintf("%s: %v\n", key, value))
		}
		config.Content = content.String()
	}

	app.Configs[name] = config
	return nil
}

func parseKubernetesSecret(app *Application, resource map[string]interface{}) error {
	metadata, _ := resource["metadata"].(map[string]interface{})
	data, _ := resource["data"].(map[string]interface{})

	name, _ := metadata["name"].(string)
	if name == "" {
		return fmt.Errorf("secret missing name")
	}

	secret := &Secret{
		Name: name,
	}

	// For simplicity, we'll store the data as environment variable references
	if len(data) > 0 {
		var envVars []string
		for key := range data {
			envVars = append(envVars, key)
		}
		secret.Environment = strings.Join(envVars, ",")
	}

	app.Secrets[name] = secret
	return nil
}

func parseKubernetesPVC(app *Application, resource map[string]interface{}) error {
	metadata, _ := resource["metadata"].(map[string]interface{})
	spec, _ := resource["spec"].(map[string]interface{})

	name, _ := metadata["name"].(string)
	if name == "" {
		return fmt.Errorf("pvc missing name")
	}

	volume := &Volume{
		Name:   name,
		Driver: "persistentVolumeClaim",
	}

	if resources, ok := spec["resources"].(map[string]interface{}); ok {
		if requests, ok := resources["requests"].(map[string]interface{}); ok {
			if storage, ok := requests["storage"].(string); ok {
				volume.DriverOpts = map[string]string{"storage": storage}
			}
		}
	}

	app.Volumes[name] = volume
	return nil
}

func parseKubernetesIngress(app *Application, resource map[string]interface{}) error {
	spec, _ := resource["spec"].(map[string]interface{})

	if rules, ok := spec["rules"].([]interface{}); ok {
		for _, rule := range rules {
			if ruleMap, ok := rule.(map[string]interface{}); ok {
				if host, ok := ruleMap["host"].(string); ok {
					// Store ingress info in extensions
					if app.Extensions == nil {
						app.Extensions = make(map[string]interface{})
					}
					if ingress, ok := app.Extensions["ingress"].([]string); ok {
						app.Extensions["ingress"] = append(ingress, host)
					} else {
						app.Extensions["ingress"] = []string{host}
					}
				}
			}
		}
	}

	return nil
}

// SerializeKubernetesYAML converts an Application to Kubernetes YAML
func SerializeKubernetesYAML(app *Application) (string, error) {
	var documents []string

	// Create ConfigMaps
	for name, config := range app.Configs {
		doc, err := serializeKubernetesConfigMap(name, config)
		if err != nil {
			return "", fmt.Errorf("failed to serialize configmap %s: %w", name, err)
		}
		documents = append(documents, doc)
	}

	// Create Secrets
	for name, secret := range app.Secrets {
		doc, err := serializeKubernetesSecret(name, secret)
		if err != nil {
			return "", fmt.Errorf("failed to serialize secret %s: %w", name, err)
		}
		documents = append(documents, doc)
	}

	// Create PersistentVolumeClaims
	for name, volume := range app.Volumes {
		doc, err := serializeKubernetesPVC(name, volume)
		if err != nil {
			return "", fmt.Errorf("failed to serialize pvc %s: %w", name, err)
		}
		documents = append(documents, doc)
	}

	// Create Deployments and Services
	for name, service := range app.Services {
		// Deployment
		deploymentDoc, err := serializeKubernetesDeployment(name, service)
		if err != nil {
			return "", fmt.Errorf("failed to serialize deployment %s: %w", name, err)
		}
		documents = append(documents, deploymentDoc)

		// Service (if it has ports)
		if len(service.Ports) > 0 {
			serviceDoc, err := serializeKubernetesService(name, service)
			if err != nil {
				return "", fmt.Errorf("failed to serialize service %s: %w", name, err)
			}
			documents = append(documents, serviceDoc)
		}
	}

	return strings.Join(documents, "\n---\n"), nil
}

func serializeKubernetesDeployment(name string, service *Service) (string, error) {
	deployment := map[string]interface{}{
		"apiVersion": "apps/v1",
		"kind":       "Deployment",
		"metadata": map[string]interface{}{
			"name": name,
		},
		"spec": map[string]interface{}{
			"replicas": 1,
			"selector": map[string]interface{}{
				"matchLabels": map[string]interface{}{
					"app": name,
				},
			},
			"template": map[string]interface{}{
				"metadata": map[string]interface{}{
					"labels": map[string]interface{}{
						"app": name,
					},
				},
				"spec": map[string]interface{}{
					"containers": []map[string]interface{}{
						{
							"name":  name,
							"image": service.Image,
						},
					},
				},
			},
		},
	}

	container := deployment["spec"].(map[string]interface{})["template"].(map[string]interface{})["spec"].(map[string]interface{})["containers"].([]map[string]interface{})[0]

	// Add command
	if len(service.Command) > 0 {
		container["command"] = service.Command
	}

	// Add environment variables
	if len(service.Environment) > 0 {
		var env []map[string]interface{}
		for key, value := range service.Environment {
			env = append(env, map[string]interface{}{
				"name":  key,
				"value": value,
			})
		}
		container["env"] = env
	}

	// Add ports
	if len(service.Ports) > 0 {
		var ports []map[string]interface{}
		for _, port := range service.Ports {
			portSpec := map[string]interface{}{
				"containerPort": parseInt(port.ContainerPort),
			}
			if port.Protocol != "" && port.Protocol != "tcp" {
				portSpec["protocol"] = strings.ToUpper(port.Protocol)
			}
			ports = append(ports, portSpec)
		}
		container["ports"] = ports
	}

	// Add volume mounts
	if len(service.Volumes) > 0 {
		var volumeMounts []map[string]interface{}
		var volumes []map[string]interface{}

		for _, vol := range service.Volumes {
			volumeMounts = append(volumeMounts, map[string]interface{}{
				"name":       vol.Source,
				"mountPath": vol.Target,
				"readOnly":  vol.ReadOnly,
			})

			volumes = append(volumes, map[string]interface{}{
				"name": vol.Source,
				"emptyDir": map[string]interface{}{},
			})
		}

		container["volumeMounts"] = volumeMounts
		deployment["spec"].(map[string]interface{})["template"].(map[string]interface{})["spec"].(map[string]interface{})["volumes"] = volumes
	}

	data, err := yaml.Marshal(deployment)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

func serializeKubernetesService(name string, service *Service) (string, error) {
	k8sService := map[string]interface{}{
		"apiVersion": "v1",
		"kind":       "Service",
		"metadata": map[string]interface{}{
			"name": name,
		},
		"spec": map[string]interface{}{
			"selector": map[string]interface{}{
				"app": name,
			},
			"ports": []map[string]interface{}{},
		},
	}

	var ports []map[string]interface{}
	for _, port := range service.Ports {
		portSpec := map[string]interface{}{
			"port":       parseInt(port.HostPort),
			"targetPort": parseInt(port.ContainerPort),
		}
		if port.Protocol != "" && port.Protocol != "tcp" {
			portSpec["protocol"] = strings.ToUpper(port.Protocol)
		}
		ports = append(ports, portSpec)
	}

	k8sService["spec"].(map[string]interface{})["ports"] = ports

	data, err := yaml.Marshal(k8sService)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

func serializeKubernetesConfigMap(name string, config *Config) (string, error) {
	configMap := map[string]interface{}{
		"apiVersion": "v1",
		"kind":       "ConfigMap",
		"metadata": map[string]interface{}{
			"name": name,
		},
		"data": map[string]string{
			name + ".yaml": config.Content,
		},
	}

	data, err := yaml.Marshal(configMap)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

func serializeKubernetesSecret(name string, secret *Secret) (string, error) {
	k8sSecret := map[string]interface{}{
		"apiVersion": "v1",
		"kind":       "Secret",
		"metadata": map[string]interface{}{
			"name": name,
		},
		"type": "Opaque",
		"data": map[string]string{
			"value": "dGVzdA==", // base64 encoded "test"
		},
	}

	data, err := yaml.Marshal(k8sSecret)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

func serializeKubernetesPVC(name string, volume *Volume) (string, error) {
	pvc := map[string]interface{}{
		"apiVersion": "v1",
		"kind":       "PersistentVolumeClaim",
		"metadata": map[string]interface{}{
			"name": name,
		},
		"spec": map[string]interface{}{
			"accessModes": []string{"ReadWriteOnce"},
			"resources": map[string]interface{}{
				"requests": map[string]interface{}{
					"storage": "1Gi",
				},
			},
		},
	}

	// Set storage size from driver opts
	if volume.DriverOpts != nil {
		if storage, ok := volume.DriverOpts["storage"]; ok {
			pvc["spec"].(map[string]interface{})["resources"].(map[string]interface{})["requests"].(map[string]interface{})["storage"] = storage
		}
	}

	data, err := yaml.Marshal(pvc)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

// Helper functions
func interfaceSliceToStringSlice(slice []interface{}) []string {
	var result []string
	for _, item := range slice {
		if str, ok := item.(string); ok {
			result = append(result, str)
		}
	}
	return result
}

func parseInt(s string) int {
	if i, err := strconv.Atoi(s); err == nil {
		return i
	}
	return 0
}