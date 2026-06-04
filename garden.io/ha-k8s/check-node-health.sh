#!/bin/bash
# Check health of all cluster nodes

NODES=("micklethefickle.bolabaden.org" "cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org" "cloudserver3.bolabaden.org" "blackboar.bolabaden.org")

check_node() {
    local node=$1
    echo "=== Checking $node ==="
    
    # SSH connectivity
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$node "echo 'SSH OK'" &>/dev/null; then
        echo "✅ SSH: Accessible"
        
        # Kubernetes node status
        if ssh ubuntu@$node "kubectl get node $node --no-headers 2>/dev/null" &>/dev/null; then
            STATUS=$(ssh ubuntu@$node "kubectl get node $node --no-headers 2>/dev/null | awk '{print \$2}'")
            echo "✅ K8s Node Status: $STATUS"
        else
            echo "⚠️  K8s: Not configured or not accessible"
        fi
        
        # System health
        UPTIME=$(ssh ubuntu@$node "uptime" 2>/dev/null | awk '{print $3,$4}' | sed 's/,//')
        echo "✅ Uptime: $UPTIME"
        
        # Disk space
        DISK=$(ssh ubuntu@$node "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null)
        echo "✅ Disk Usage: $DISK"
    else
        echo "❌ SSH: Not accessible"
    fi
    echo ""
}

for node in "${NODES[@]}"; do
    check_node "$node"
done
