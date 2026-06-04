#!/bin/bash
# Set up external etcd cluster for HA

ETCD_NODES=("micklethefickle.bolabaden.org" "cloudserver1.bolabaden.org" "cloudserver2.bolabaden.org")
ETCD_VERSION="3.5.9"

for i in "${!ETCD_NODES[@]}"; do
    node="${ETCD_NODES[$i]}"
    echo "Setting up etcd on $node (member $i)..."
    ssh ubuntu@$node "sudo bash -c '
        mkdir -p /etc/etcd /var/lib/etcd
        wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
        tar xzf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
        cp etcd-v${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
        chmod +x /usr/local/bin/etcd*
    '"
done
