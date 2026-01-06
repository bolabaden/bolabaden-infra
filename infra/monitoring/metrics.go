package monitoring

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// NodeMetrics represents current resource usage on a node
type NodeMetrics struct {
	CPUPercent    float64
	MemoryPercent float64
	MemoryUsed    int64 // bytes
	MemoryTotal   int64 // bytes
	Timestamp     time.Time
}

// MetricsCollector collects node resource metrics
type MetricsCollector struct {
	checkInterval time.Duration
}

// NewMetricsCollector creates a new metrics collector
func NewMetricsCollector() *MetricsCollector {
	return &MetricsCollector{
		checkInterval: 10 * time.Second,
	}
}

// CollectMetrics collects current node metrics using system commands
func (mc *MetricsCollector) CollectMetrics(ctx context.Context) (*NodeMetrics, error) {
	metrics := &NodeMetrics{
		Timestamp: time.Now(),
	}

	// Collect CPU usage
	cpuPercent, err := mc.getCPUPercent(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get CPU percent: %w", err)
	}
	metrics.CPUPercent = cpuPercent

	// Collect memory usage
	memPercent, memUsed, memTotal, err := mc.getMemoryUsage(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get memory usage: %w", err)
	}
	metrics.MemoryPercent = memPercent
	metrics.MemoryUsed = memUsed
	metrics.MemoryTotal = memTotal

	return metrics, nil
}

// getCPUPercent gets CPU usage percentage using top/htop or /proc/stat
func (mc *MetricsCollector) getCPUPercent(ctx context.Context) (float64, error) {
	// Try using top command first (more accurate)
	cmd := exec.CommandContext(ctx, "sh", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'")
	output, err := cmd.Output()
	if err == nil {
		// Parse output
		lines := strings.TrimSpace(string(output))
		if len(lines) > 0 {
			parts := strings.Fields(lines)
			if len(parts) > 0 {
				if cpu, err := strconv.ParseFloat(parts[0], 64); err == nil {
					return cpu, nil
				}
			}
		}
	}

	// Fallback to /proc/stat method
	cmd = exec.CommandContext(ctx, "sh", "-c", "grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4+$5)} END {print usage}'")
	output, err = cmd.Output()
	if err != nil {
		return 0, fmt.Errorf("failed to get CPU usage: %w", err)
	}

	cpuStr := strings.TrimSpace(string(output))
	cpu, err := strconv.ParseFloat(cpuStr, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse CPU usage: %w", err)
	}

	return cpu, nil
}

// getMemoryUsage gets memory usage using free command
func (mc *MetricsCollector) getMemoryUsage(ctx context.Context) (percent float64, used int64, total int64, err error) {
	cmd := exec.CommandContext(ctx, "free", "-b")
	output, err := cmd.Output()
	if err != nil {
		return 0, 0, 0, fmt.Errorf("failed to get memory info: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	if len(lines) < 2 {
		return 0, 0, 0, fmt.Errorf("unexpected free output format")
	}

	// Parse Mem: line
	memLine := lines[1]
	fields := strings.Fields(memLine)
	if len(fields) < 3 {
		return 0, 0, 0, fmt.Errorf("unexpected free output format")
	}

	total, err = strconv.ParseInt(fields[1], 10, 64)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("failed to parse total memory: %w", err)
	}

	used, err = strconv.ParseInt(fields[2], 10, 64)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("failed to parse used memory: %w", err)
	}

	if total > 0 {
		percent = float64(used) / float64(total) * 100.0
	}

	return percent, used, total, nil
}

// EvaluateResourceThreshold evaluates if a resource threshold is exceeded
// threshold format: "cpu>80%" or "memory>90%"
func EvaluateResourceThreshold(metrics *NodeMetrics, threshold string) (bool, error) {
	threshold = strings.TrimSpace(threshold)
	if threshold == "" {
		return false, nil
	}

	// Parse threshold (e.g., "cpu>80%" or "memory>90%")
	var resource string
	var operator string
	var valueStr string

	// Extract resource type
	if strings.HasPrefix(strings.ToLower(threshold), "cpu") {
		resource = "cpu"
		threshold = threshold[3:]
	} else if strings.HasPrefix(strings.ToLower(threshold), "memory") {
		resource = "memory"
		threshold = threshold[6:]
	} else {
		return false, fmt.Errorf("unknown resource type in threshold: %s", threshold)
	}

	// Extract operator and value
	if strings.HasPrefix(threshold, ">") {
		operator = ">"
		valueStr = strings.TrimSuffix(threshold[1:], "%")
	} else if strings.HasPrefix(threshold, "<") {
		operator = "<"
		valueStr = strings.TrimSuffix(threshold[1:], "%")
	} else if strings.HasPrefix(threshold, ">=") {
		operator = ">="
		valueStr = strings.TrimSuffix(threshold[2:], "%")
	} else if strings.HasPrefix(threshold, "<=") {
		operator = "<="
		valueStr = strings.TrimSuffix(threshold[2:], "%")
	} else {
		return false, fmt.Errorf("invalid operator in threshold: %s", threshold)
	}

	value, err := strconv.ParseFloat(valueStr, 64)
	if err != nil {
		return false, fmt.Errorf("failed to parse threshold value: %w", err)
	}

	// Get current resource usage
	var currentValue float64
	if resource == "cpu" {
		currentValue = metrics.CPUPercent
	} else if resource == "memory" {
		currentValue = metrics.MemoryPercent
	}

	// Evaluate threshold
	switch operator {
	case ">":
		return currentValue > value, nil
	case "<":
		return currentValue < value, nil
	case ">=":
		return currentValue >= value, nil
	case "<=":
		return currentValue <= value, nil
	default:
		return false, fmt.Errorf("unsupported operator: %s", operator)
	}
}
