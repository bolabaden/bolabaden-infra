#!/bin/bash
# Set up external etcd cluster on control plane nodes

ETCD_NODES=("micklethefickle.bolabaden.org" "cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
ETCD_VERSION="3.5.9"

echo "=== Setting up External etcd Cluster ==="

for i in "${!ETCD_NODES[@]}"; do
    node="${ETCD_NODES[$i]}"
    name="etcd-$i"
    ip=$(ssh ubuntu@$node "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "")
    
    echo "Configuring etcd on $node ($name)..."
    ssh ubuntu@$node "sudo bash -c '
        mkdir -p /etc/etcd /var/lib/etcd
        cat > /etc/systemd/system/etcd.service << EOF
[Unit]
Description=etcd
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name=$name \\
  --data-dir=/var/lib/etcd \\
  --listen-client-urls=https://$ip:2379 \\
  --advertise-client-urls=https://$ip:2379 \\
  --listen-peer-urls=https://$ip:2380 \\
  --initial-advertise-peer-urls=https://$ip:2380 \\
  --initial-cluster=etcd-0=https://${ETCD_NODES[0]}:2380,etcd-1=https://${ETCD_NODES[1]}:2380,etcd-2=https://${ETCD_NODES[2]}:2380 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster-state=new \\
  --client-cert-auth \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --cert-file=/etc/etcd/server.crt \\
  --key-file=/etc/etcd/server.key \\
  --peer-client-cert-auth \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-cert-file=/etc/etcd/peer.crt \\
  --peer-key-file=/etc/etcd/peer.key
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    '"
done

echo "✅ etcd cluster configuration created"
echo "Note: Generate certificates before starting etcd"
