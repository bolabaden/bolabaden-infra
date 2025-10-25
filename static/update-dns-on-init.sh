
#!/bin/bash
# Detect external address and domain automatically
source /tooling-scripts/cloudflare-scripts.sh

# Get external IP
MY_NODE_IP=$(curl -s ifconfig.me)

# Auto-detect domain from Cloudflare zones
DNS_DOMAIN=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer ${CF_API_KEY:?}" \
    -H "Content-Type: application/json" | \
    jq -r '.result[0].name')

# Get hostname for this node
MY_NODE_NAME=$(hostname)

# Create DNS record for this node
manage_cloudflare_record $DNS_DOMAIN $MY_NODE_NAME.$DNS_DOMAIN A $MY_NODE_IP

# Create service subdomain (using hostname as prefix)
manage_cloudflare_record $DNS_DOMAIN $MY_NODE_NAME-services.$DNS_DOMAIN CNAME $MY_NODE_NAME.$DNS_DOMAIN