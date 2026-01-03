package main

import (
	"context"
	"log"
	"time"
)

// WarpMonitor monitors health of the warp-nat-gateway container by checking a
// simple egress command. This is a lightweight placeholder; production logic
// can be extended to execute the existing warp-monitor script.
type WarpMonitor struct {
	checkInterval time.Duration
}

func NewWarpMonitor() *WarpMonitor {
	return &WarpMonitor{
		checkInterval: 30 * time.Second,
	}
}

// Start begins periodic health checks. On failure, it logs a warning; recovery
// actions can be added later (restart gateway, run setup script, etc.).
func (wm *WarpMonitor) Start(ctx context.Context) {
	ticker := time.NewTicker(wm.checkInterval)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := wm.checkOnce(ctx); err != nil {
					log.Printf("warp monitor: detected issue with warp-nat-gateway: %v", err)
				}
			case <-ctx.Done():
				return
			}
		}
	}()
}

func (wm *WarpMonitor) checkOnce(ctx context.Context) error {
	// Placeholder: In production, we would run an HTTP/HTTPS probe through
	// warp-nat-net (similar to curl ifconfig.me) to verify egress via WARP.
	_ = ctx
	return nil
}
