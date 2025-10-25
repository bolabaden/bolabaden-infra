#!/bin/bash
function cleanup_dns_on_shutdown {
    echo "Received SIGTERM, cleaning up DNS entries..."
    source /tooling-scripts/cloudflare-scripts.sh
    DNS_DOMAIN=elfhosted.com
    delete_cloudflare_record $DNS_DOMAIN $ELF_TENANT_NAME-plex.$DNS_DOMAIN CNAME
}
# When we terminate, delete the DNS record
trap cleanup_dns_on_shutdown SIGTERM
# Hang around doing nothing until terminated
while true
do
    echo "Waiting for SIGTERM to remove DNS entry"
    sleep infinity
done