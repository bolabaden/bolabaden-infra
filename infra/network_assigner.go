package main

// assignNetworks determines which networks a service should join based on labels
// and defaults. Explicit networks in the Service definition are honored; if
// none are provided, it derives networks from labels.
func assignNetworks(svc Service) []string {
	// If networks already specified, ensure backend is present at minimum.
	if len(svc.Networks) > 0 {
		return dedupeNetworks(ensureBackendDefault(svc.Networks))
	}

	networks := []string{"backend"}

	if svc.Labels != nil {
		if svc.Labels["traefik.enable"] == "true" {
			networks = append(networks, "publicnet")
		}
		if svc.Labels["network.warp.enabled"] == "true" {
			networks = append(networks, "warp-nat-net")
		}
		if svc.Labels["network.backend.only"] == "true" {
			networks = []string{"backend"}
		}
	}

	return dedupeNetworks(networks)
}

func ensureBackendDefault(nets []string) []string {
	for _, n := range nets {
		if n == "backend" {
			return nets
		}
	}
	return append([]string{"backend"}, nets...)
}

func dedupeNetworks(nets []string) []string {
	seen := map[string]struct{}{}
	result := []string{}
	for _, n := range nets {
		if n == "" {
			continue
		}
		if _, ok := seen[n]; ok {
			continue
		}
		seen[n] = struct{}{}
		result = append(result, n)
	}
	return result
}
