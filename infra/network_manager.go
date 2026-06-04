package main

// ensureDefaultNetworks populates default network definitions if they are
// missing from the provided config. This keeps network creation consistent
// across nodes without requiring compose files.
func ensureDefaultNetworks(cfg *Config) {
	if cfg.Networks == nil {
		cfg.Networks = map[string]NetworkConfig{}
	}

	defaults := map[string]NetworkConfig{
		"backend": {
			Name:       "backend",
			Driver:     "bridge",
			Subnet:     getEnv("BACKEND_SUBNET", "10.0.7.0/24"),
			Gateway:    getEnv("BACKEND_GATEWAY", "10.0.7.1"),
			BridgeName: "br_backend",
			Attachable: true,
		},
		"publicnet": {
			Name:       "publicnet",
			Driver:     "bridge",
			Subnet:     getEnv("PUBLICNET_SUBNET", "10.76.0.0/16"),
			Gateway:    getEnv("PUBLICNET_GATEWAY", "10.76.0.1"),
			BridgeName: "br_publicnet",
			Attachable: true,
		},
		"warp-nat-net": {
			Name:       "warp-nat-net",
			Driver:     "bridge",
			Subnet:     getEnv("WARP_NAT_NET_SUBNET", "10.0.2.0/24"),
			Gateway:    getEnv("WARP_NAT_NET_GATEWAY", "10.0.2.1"),
			BridgeName: "br_warp-nat-net",
			Attachable: true,
		},
	}

	for name, net := range defaults {
		if _, ok := cfg.Networks[name]; !ok {
			cfg.Networks[name] = net
		}
	}
}
