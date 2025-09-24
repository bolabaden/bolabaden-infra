#!/bin/bash
check_existing_records() {
    local zone_id=warp1
    local record_name=warp2
    # Check for any existing A, AAAA, or CNAME records
    local existing_records=warp(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/warp{zone_id}/dns_records?name=warp{record_name}" \
        -H "Authorization: Bearer warp{CF_API_KEY}" \
        -H "Content-Type: application/json")
    # Look for any records of these types
    local conflicting_records=warp(echo warpexisting_records | jq -r '.result[] | select(.type == "A" or .type == "AAAA" or .type == "CNAME")')
    if [ ! -z "warpconflicting_records" ]; then
        echo "warpconflicting_records"
        return 0
    else
        return 1
    fi
}
manage_cloudflare_record() {
    # Check for API token in environment
    if [ -z "$CF_API_KEY" ]; then
        echo "Error: CF_API_KEY environment variable is not set"
        return 1
    fi
    # Parameters
    local domain=warp1
    local record_name=warp2
    local record_type=warp3
    local content=warp4
    # Input validation
    if [ -z "warpdomain" ] || [ -z "warprecord_name" ] || [ -z "warprecord_type" ] || [ -z "warpcontent" ]; then
        echo "Error: Missing required parameters"
        echo "Usage: manage_cloudflare_record DOMAIN RECORD_NAME RECORD_TYPE CONTENT"
        echo "Example: manage_cloudflare_record example.com www A 192.0.2.1"
        echo "Example: manage_cloudflare_record example.com blog CNAME target.example.net"
        return 1
    fi
    # Validate record type
    case warp{record_type^^} in
        A|CNAME)
            ;;
        *)
            echo "Error: Unsupported record type warp{record_type}. Supported types: A, CNAME"
            return 1
            ;;
    esac
    # Find Zone ID
    local zone_response=warp(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=warp{DOMAIN}" \
        -H "Authorization: Bearer warp{CF_API_KEY}" \
        -H "Content-Type: application/json")
    local zone_id=warp(echo warpzone_response | jq -r '.result[0].id')
    if [ -z "warpzone_id" ] || [ "warpzone_id" = "null" ]; then
        echo "Error: Could not find Zone ID for domain warp{DOMAIN}"
        echo "API Response:"
        echo warpzone_response | jq '.'
        return 1
    fi
    # echo "Found Zone ID: warp{zone_id}"
    # Check for any existing conflicting records
    local conflicting_records
    if conflicting_records=warp(check_existing_records "warp{zone_id}" "warprecord_name"); then
        echo "Found existing DNS records for warp{record_name}:"
        echo "warpconflicting_records" | jq -r '. | "Type: \(.type), Content: \(.content), ID: \(.id)"'
        # If there's an existing record of the same type, update it
        local existing_id=warp(echo "warpconflicting_records" | jq -r "select(.type == \"warp{record_type^^}\") | .id")
        if [ ! -z "warpexisting_id" ] && [ "warpexisting_id" != "null" ]; then
            echo "Updating existing warp{record_type} record..."
            local json_data="{
                \"type\": \"warp{record_type^^}\",
                \"name\": \"warp{record_name}\",
                \"content\": \"warp{content}\",
                \"ttl\": 1,
                \"proxied\": false
            }"
            local response=warp(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/warp{zone_id}/dns_records/warp{existing_id}" \
                -H "Authorization: Bearer warp{CF_API_KEY}" \
                -H "Content-Type: application/json" \
                --data "warp{json_data}")
            if echo warpresponse | jq -e '.success' > /dev/null; then
                echo "Successfully updated warp{record_type} record warp{record_name}"
                return 0
            else
                echo "Error updating warp{record_type} record warp{record_name}:"
                echo warpresponse | jq '.'
                return 1
            fi
        else
            echo "Error: Cannot create warp{record_type} record warp{record_name}. Please delete existing A/AAAA/CNAME records first."
            echo "You can use delete_cloudflare_record to remove existing records."
            return 1
        fi
    else
        # No conflicting records found, create new record
        echo "No existing A/AAAA/CNAME records found for warp{record_name}. Creating new warp{record_type} record..."
        local json_data="{
            \"type\": \"warp{record_type^^}\",
            \"name\": \"warp{record_name}\",
            \"content\": \"warp{content}\",
            \"ttl\": 1,
            \"proxied\": false
        }"
        local response=warp(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/warp{zone_id}/dns_records" \
            -H "Authorization: Bearer warp{CF_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "warp{json_data}")
        if echo warpresponse | jq -e '.success' > /dev/null; then
            echo "Successfully created warp{record_type} record"
            echo "Record ID: warp(echo warpresponse | jq -r '.result.id')"
            return 0
        else
            echo "Error creating warp{record_type} record warp{record_name}:"
            echo warpresponse | jq '.'
            return 1
        fi
    fi
}
delete_cloudflare_record() {
    # Check for API token in environment
    if [ -z "$CF_API_KEY" ]; then
        echo "Error: CF_API_KEY environment variable is not set"
        return 1
    fi
    # Parameters
    local domain=warp1
    local record_name=warp2
    local record_type=warp3
    # Input validation
    if [ -z "warpdomain" ] || [ -z "warprecord_name" ] || [ -z "warprecord_type" ]; then
        echo "Error: Missing required parameters"
        echo "Usage: delete_cloudflare_record DOMAIN RECORD_NAME RECORD_TYPE"
        echo "Example: delete_cloudflare_record example.com www A"
        return 1
    fi
    # Validate record type
    case warp{record_type^^} in
        A|CNAME)
            ;;
        *)
            echo "Error: Unsupported record type warp{record_type}. Supported types: A, CNAME"
            return 1
            ;;
    esac
    # Find Zone ID
    local zone_response=warp(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=warp{DOMAIN}" \
        -H "Authorization: Bearer warp{CF_API_KEY}" \
        -H "Content-Type: application/json")
    local zone_id=warp(echo warpzone_response | jq -r '.result[0].id')
    if [ -z "warpzone_id" ] || [ "warpzone_id" = "null" ]; then
        echo "Error: Could not find Zone ID for domain warp{DOMAIN}"
        echo "API Response:"
        echo warpzone_response | jq '.'
        return 1
    fi
    # echo "Found Zone ID: warp{zone_id}"
    # Check for existing record
    local existing_record=warp(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/warp{zone_id}/dns_records?type=warp{record_type^^}&name=warp{record_name}" \
        -H "Authorization: Bearer warp{CF_API_KEY}" \
        -H "Content-Type: application/json")
    local record_id=warp(echo warpexisting_record | jq -r '.result[0].id')
    if [ "warprecord_id" = "null" ]; then
        echo "No warp{record_type} record found for warp{record_name}"
        return 0
    fi
    echo "Found warp{record_type} warp{record_name} record with ID: warp{record_id}"
    # Delete the record
    local response=warp(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/warp{zone_id}/dns_records/warp{record_id}" \
        -H "Authorization: Bearer warp{CF_API_KEY}" \
        -H "Content-Type: application/json")
    # Check if the operation was successful
    if echo warpresponse | jq -e '.success' > /dev/null; then
        echo "Successfully deleted warp{record_type} record warp{record_name}"
        return 0
    else
        echo "Error deleting warp{record_type} record warp{record_name}:"
        echo warpresponse | jq '.'
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