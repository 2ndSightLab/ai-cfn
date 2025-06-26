#!/bin/bash -e

is_valid_aws_service() {
    local service_name=$1
    
    # Check if service name is provided
    if [ -z "$service_name" ]; then
        echo "Error: Service name must be provided." >&2
        exit
    fi
    
    # Fetch the list of valid AWS service names
    local aws_services=$(curl -s https://servicereference.us-east-1.amazonaws.com/v1/service-list.json | jq -r '.services[].id')
    
    # Check if curl or jq command failed
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve AWS service list." >&2
        exit
    fi
    
    # Check if the service name is in the list
    if [[ $aws_services =~ (^|[[:space:]])$service_name($|[[:space:]]) ]]; then
        return 0  # Valid service
    else
        echo "Error: '$service_name' is not a valid AWS service. Enter for a list of service names" >&2
        read ok
        list_aws_service_names
        exit
    fi
}
