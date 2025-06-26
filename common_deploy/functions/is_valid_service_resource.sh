#!/bin/bash
is_valid_service_resource() {
    local service_name=$1
    local resource_type=$2
    
    # Check if both parameters are provided
    if [ -z "$service_name" ] || [ -z "$resource_type" ]; then
        echo "Error: Both service name and resource type must be provided." >&2
        return 1
    fi
    
    # First check if the service is valid
    is_valid_aws_service "$service_name"
    if [ $? -ne 0 ]; then
        # No need to output an error message here as is_valid_aws_service already does that
        return 1
    fi
    
    # Fetch the JSON data for the service
    local json_data=$(curl -s "https://servicereference.us-east-1.amazonaws.com/v1/${service_name}/${service_name}.json")
    
    # Check if curl command failed
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve resource information for service '$service_name'." >&2
        return 1
    fi
    
    # Check if the resource type exists in the JSON data
    if echo "$json_data" | jq -e ".ResourceTypes | has(\"$resource_type\")" > /dev/null; then
        return 0  # Valid resource type
    else
        echo "Error: Resource type '$resource_type' is not valid for service '$service_name'." >&2
        return 1  # Invalid resource type
    fi
}
