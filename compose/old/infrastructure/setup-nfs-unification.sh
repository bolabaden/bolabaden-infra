#!/bin/bash
# Script to enable or disable NFS unification for Docker Swarm

# Get the hostname of the manager node
MANAGER_HOSTNAME=$(docker node ls --format '{{.Hostname}}' | grep -i manager | head -1)

if [ "$1" == "enable" ]; then
    echo "Enabling NFS unification for Docker Swarm..."
    
    # Export the environment variables needed
    export UNIFY_WITH_NFS_MOUNTING=true
    export NFS_SERVER=$MANAGER_HOSTNAME
    
    # Create a .env file to store these settings
    cat > .env << EOF
UNIFY_WITH_NFS_MOUNTING=true
NFS_SERVER=$MANAGER_HOSTNAME
EOF
    
    echo "NFS unification enabled. The ROOT_DIR will be shared across all swarm nodes."
    echo "To apply changes, restart your stack with 'docker-compose down && docker-compose up -d'"
    
elif [ "$1" == "disable" ]; then
    echo "Disabling NFS unification for Docker Swarm..."
    
    # Remove the environment variables if they exist
    unset UNIFY_WITH_NFS_MOUNTING
    unset NFS_SERVER
    
    # Update .env file
    if [ -f .env ]; then
        sed -i '/UNIFY_WITH_NFS_MOUNTING/d' .env  # Remove the lines containing these variables.
        sed -i '/NFS_SERVER/d' .env
    fi
    
    echo "NFS unification disabled. Each node will use its local ROOT_DIR."
    echo "To apply changes, restart your stack with 'docker-compose down && docker-compose up -d'"
    
else
    echo "Usage: $0 [enable|disable]"
    echo ""
    echo "This script configures NFS unification for Docker Swarm."
    echo "  enable: Share the ROOT_DIR across all swarm nodes using NFS"
    echo "  disable: Use local ROOT_DIR on each node (default behavior)"
fi 