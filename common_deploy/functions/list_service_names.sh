#!/bin/bash
list_service_names(){
    # Fetch the service list from the AWS service reference endpoint
    response=$(curl -s https://servicereference.us-east-1.amazonaws.com/v1/service-list.json)
    
    # Check if curl command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch service list." >&2
        return 1
    fi
    
    # Extract and display service names using jq
    # Check if jq is installed
    if command -v jq &> /dev/null; then
        echo "Available AWS Services:"
        jq -r '.services[] | .name' <<< "$response" | sort
    else
        echo "Error: jq is not installed. Please install jq to parse JSON." >&2
        echo "You can install it using: sudo apt-get install jq (Debian/Ubuntu) or sudo yum install jq (Amazon Linux/CentOS)" >&2
        return 1
    fi
}
