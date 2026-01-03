package dns

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/cloudflare/cloudflare-go"
	"golang.org/x/time/rate"
)

// DNSReconciler manages Cloudflare DNS records for the cluster
type DNSReconciler struct {
	api        *cloudflare.API
	zoneID     string
	domain     string
	limiter    *rate.Limiter
	mu         sync.RWMutex
	lastUpdate map[string]time.Time // Record name -> last update time
}

// Config holds configuration for the DNS reconciler
type Config struct {
	APIToken   string // Cloudflare API token
	ZoneID     string // Cloudflare zone ID
	Domain     string // Domain name (e.g., "bolabaden.org")
	RateLimit  int    // Requests per second (default: 4)
	BurstLimit int    // Burst limit (default: 10)
}

// NewDNSReconciler creates a new DNS reconciler
func NewDNSReconciler(config *Config) (*DNSReconciler, error) {
	api, err := cloudflare.NewWithAPIToken(config.APIToken)
	if err != nil {
		return nil, fmt.Errorf("failed to create Cloudflare API client: %w", err)
	}

	rateLimit := config.RateLimit
	if rateLimit == 0 {
		rateLimit = 4 // Cloudflare default rate limit
	}

	burstLimit := config.BurstLimit
	if burstLimit == 0 {
		burstLimit = 10
	}

	return &DNSReconciler{
		api:        api,
		zoneID:     config.ZoneID,
		domain:     config.Domain,
		limiter:    rate.NewLimiter(rate.Limit(rateLimit), burstLimit),
		lastUpdate: make(map[string]time.Time),
	}, nil
}

// UpdateLBLeaderRecord updates the apex and wildcard records to point to the LB leader
func (dr *DNSReconciler) UpdateLBLeaderRecord(lbLeaderIP string) error {
	records := []string{
		dr.domain,        // apex: bolabaden.org
		"*." + dr.domain, // wildcard: *.bolabaden.org
	}

	var errors []error
	for _, recordName := range records {
		if err := dr.updateRecord(recordName, "A", lbLeaderIP, 1, false); err != nil {
			errors = append(errors, fmt.Errorf("failed to update %s: %w", recordName, err))
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("failed to update LB leader records: %v", errors)
	}

	return nil
}

// UpdateNodeWildcardRecord updates the per-node wildcard record
func (dr *DNSReconciler) UpdateNodeWildcardRecord(nodeName string, nodeIP string) error {
	recordName := fmt.Sprintf("*.%s.%s", nodeName, dr.domain)
	return dr.updateRecord(recordName, "A", nodeIP, 1, false)
}

// updateRecord updates or creates a DNS record
func (dr *DNSReconciler) updateRecord(name, recordType, content string, ttl int, proxied bool) error {
	// Rate limiting
	ctx := context.Background()
	if err := dr.limiter.Wait(ctx); err != nil {
		return fmt.Errorf("rate limit wait failed: %w", err)
	}

	// Check if we recently updated this record (drift correction - avoid unnecessary updates)
	dr.mu.RLock()
	lastUpdate, recentlyUpdated := dr.lastUpdate[name]
	dr.mu.RUnlock()

	if recentlyUpdated && time.Since(lastUpdate) < 30*time.Second {
		log.Printf("Skipping DNS update for %s (updated %v ago)", name, time.Since(lastUpdate))
		return nil
	}

	// Normalize record name (remove trailing dot if present)
	name = strings.TrimSuffix(name, ".")

	// Get existing records
	records, err := dr.api.DNSRecords(ctx, dr.zoneID, cloudflare.DNSRecord{
		Name: name,
		Type: recordType,
	})
	if err != nil {
		return fmt.Errorf("failed to list DNS records: %w", err)
	}

	// Find matching record
	var existingRecord *cloudflare.DNSRecord
	for i := range records {
		if records[i].Name == name && records[i].Type == recordType {
			existingRecord = &records[i]
			break
		}
	}

	// Check if update is needed
	if existingRecord != nil {
		if existingRecord.Content == content && existingRecord.Proxied == proxied {
			log.Printf("DNS record %s already correct, skipping update", name)
			dr.mu.Lock()
			dr.lastUpdate[name] = time.Now()
			dr.mu.Unlock()
			return nil
		}

		// Update existing record
		existingRecord.Content = content
		existingRecord.TTL = ttl
		existingRecord.Proxied = proxied

		if err := dr.api.UpdateDNSRecord(ctx, dr.zoneID, existingRecord.ID, *existingRecord); err != nil {
			return fmt.Errorf("failed to update DNS record: %w", err)
		}

		log.Printf("Updated DNS record %s -> %s", name, content)
	} else {
		// Create new record
		newRecord := cloudflare.DNSRecord{
			Type:    recordType,
			Name:    name,
			Content: content,
			TTL:     ttl,
			Proxied: proxied,
		}

		_, err := dr.api.CreateDNSRecord(ctx, dr.zoneID, newRecord)
		if err != nil {
			return fmt.Errorf("failed to create DNS record: %w", err)
		}

		log.Printf("Created DNS record %s -> %s", name, content)
	}

	// Update last update time
	dr.mu.Lock()
	dr.lastUpdate[name] = time.Now()
	dr.mu.Unlock()

	return nil
}

// ReconcileAllNodes updates DNS records for all nodes in the cluster
func (dr *DNSReconciler) ReconcileAllNodes(nodeIPs map[string]string) error {
	var errors []error

	for nodeName, nodeIP := range nodeIPs {
		if err := dr.UpdateNodeWildcardRecord(nodeName, nodeIP); err != nil {
			errors = append(errors, fmt.Errorf("failed to update node %s: %w", nodeName, err))
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("failed to reconcile all nodes: %v", errors)
	}

	return nil
}

// GetCurrentRecord retrieves the current DNS record value
func (dr *DNSReconciler) GetCurrentRecord(name, recordType string) (string, error) {
	ctx := context.Background()
	if err := dr.limiter.Wait(ctx); err != nil {
		return "", fmt.Errorf("rate limit wait failed: %w", err)
	}

	name = strings.TrimSuffix(name, ".")

	records, err := dr.api.DNSRecords(ctx, dr.zoneID, cloudflare.DNSRecord{
		Name: name,
		Type: recordType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to list DNS records: %w", err)
	}

	for _, record := range records {
		if record.Name == name && record.Type == recordType {
			return record.Content, nil
		}
	}

	return "", fmt.Errorf("record not found: %s %s", name, recordType)
}
