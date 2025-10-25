#!/bin/bash
check_existing_records() {
    local zone_id=$1
    local record_name=$2
    # Check for any existing A, AAAA, or CNAME records
    local existing_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    # Look for any records of these types
    local conflicting_records=$(echo $existing_records | jq -r '.result[] | select(.type == "A" or .type == "AAAA" or .type == "CNAME")')
    if [ ! -z "$conflicting_records" ]; then
        echo "$conflicting_records"
        return 0
    else
        return 1
    fi
}
manage_cloudflare_record() {
    # Check for API token in environment
    if [ -z "${CF_API_KEY}" ]; then
        echo "Error: CF_API_KEY environment variable is not set"
        return 1
    fi
    # Parameters
    local domain=$1
    local record_name=$2
    local record_type=$3
    local content=$4
    # Input validation
    if [ -z "$domain" ] || [ -z "$record_name" ] || [ -z "$record_type" ] || [ -z "$content" ]; then
        echo "Error: Missing required parameters"
        echo "Usage: manage_cloudflare_record DOMAIN RECORD_NAME RECORD_TYPE CONTENT"
        echo "Example: manage_cloudflare_record example.com www A 192.0.2.1"
        echo "Example: manage_cloudflare_record example.com blog CNAME target.example.net"
        return 1
    fi
    # Validate record type
    case ${record_type^^} in
        A|CNAME)
            ;;
        *)
            echo "Error: Unsupported record type ${record_type}. Supported types: A, CNAME"
            return 1
            ;;
    esac
    # Find Zone ID
    local zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    local zone_id=$(echo $zone_response | jq -r '.result[0].id')
    if [ -z "$zone_id" ] || [ "$zone_id" = "null" ]; then
        echo "Error: Could not find Zone ID for domain ${DOMAIN}"
        echo "API Response:"
        echo $zone_response | jq '.'
        return 1
    fi
    # echo "Found Zone ID: ${zone_id}"
    # Check for any existing conflicting records
    local conflicting_records
    if conflicting_records=$(check_existing_records "${zone_id}" "$record_name"); then
        echo "Found existing DNS records for ${record_name}:"
        echo "$conflicting_records" | jq -r '. | "Type: \(.type), Content: \(.content), ID: \(.id)"'
        # If there's an existing record of the same type, update it
        local existing_id=$(echo "$conflicting_records" | jq -r "select(.type == \"${record_type^^}\") | .id")
        if [ ! -z "$existing_id" ] && [ "$existing_id" != "null" ]; then
            echo "Updating existing ${record_type} record..."
            local json_data="{
                \"type\": \"${record_type^^}\",
                \"name\": \"${record_name}\",
                \"content\": \"${content}\",
                \"ttl\": 1,
                \"proxied\": false
            }"
            local response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${existing_id}" \
                -H "Authorization: Bearer ${CF_API_KEY}" \
                -H "Content-Type: application/json" \
                --data "${json_data}")
            if echo $response | jq -e '.success' > /dev/null; then
                echo "Successfully updated ${record_type} record ${record_name}"
                return 0
            else
                echo "Error updating ${record_type} record ${record_name}:"
                echo $response | jq '.'
                return 1
            fi
        else
            echo "Error: Cannot create ${record_type} record ${record_name}. Please delete existing A/AAAA/CNAME records first."
            echo "You can use delete_cloudflare_record to remove existing records."
            return 1
        fi
    else
        # No conflicting records found, create new record
        echo "No existing A/AAAA/CNAME records found for ${record_name}. Creating new ${record_type} record..."
        local json_data="{
            \"type\": \"${record_type^^}\",
            \"name\": \"${record_name}\",
            \"content\": \"${content}\",
            \"ttl\": 1,
            \"proxied\": false
        }"
        local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "Authorization: Bearer ${CF_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "${json_data}")
        if echo $response | jq -e '.success' > /dev/null; then
            echo "Successfully created ${record_type} record"
            echo "Record ID: $(echo $response | jq -r '.result.id')"
            return 0
        else
            echo "Error creating ${record_type} record ${record_name}:"
            echo $response | jq '.'
            return 1
        fi
    fi
}
delete_cloudflare_record() {
    # Check for API token in environment
    if [ -z "${CF_API_KEY}" ]; then
        echo "Error: CF_API_KEY environment variable is not set"
        return 1
    fi
    # Parameters
    local domain=$1
    local record_name=$2
    local record_type=$3
    # Input validation
    if [ -z "$domain" ] || [ -z "$record_name" ] || [ -z "$record_type" ]; then
        echo "Error: Missing required parameters"
        echo "Usage: delete_cloudflare_record DOMAIN RECORD_NAME RECORD_TYPE"
        echo "Example: delete_cloudflare_record example.com www A"
        return 1
    fi
    # Validate record type
    case ${record_type^^} in
        A|CNAME)
            ;;
        *)
            echo "Error: Unsupported record type ${record_type}. Supported types: A, CNAME"
            return 1
            ;;
    esac
    # Find Zone ID
    local zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    local zone_id=$(echo $zone_response | jq -r '.result[0].id')
    if [ -z "$zone_id" ] || [ "$zone_id" = "null" ]; then
        echo "Error: Could not find Zone ID for domain ${DOMAIN}"
        echo "API Response:"
        echo $zone_response | jq '.'
        return 1
    fi
    # echo "Found Zone ID: ${zone_id}"
    # Check for existing record
    local existing_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${record_type^^}&name=${record_name}" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    local record_id=$(echo $existing_record | jq -r '.result[0].id')
    if [ "$record_id" = "null" ]; then
        echo "No ${record_type} record found for ${record_name}"
        return 0
    fi
    echo "Found ${record_type} ${record_name} record with ID: ${record_id}"
    # Delete the record
    local response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    # Check if the operation was successful
    if echo $response | jq -e '.success' > /dev/null; then
        echo "Successfully deleted ${record_type} record ${record_name}"
        return 0
    else
        echo "Error deleting ${record_type} record ${record_name}:"
        echo $response | jq '.'
        return 1
    fi
}
# Example usage:
# export CF_API_KEY="your-api-token"
# To handle the error case you encountered:
# 1. First delete any existing conflicting records:
# delete_cloudflare_record "example.com" "blog" "A"
# delete_cloudflare_record "example.com" "blog" "AAAA"
# 2. Then create your new record:
# manage_cloudflare_record "example.com" "blog" "CNAME" "target.example.net"