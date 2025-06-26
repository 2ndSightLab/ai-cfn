#!/bin/bash
list_service_resource_names() {
  SERVICE_NAME="$1"
  
  # Check if the service is valid
  if ! is_valid_aws_service "$SERVICE_NAME"; then
    echo "Service '$SERVICE_NAME' not found in the service list."
    echo "Available services:"
    curl -s "https://servicereference.us-east-1.amazonaws.com/v1/service-list.json" | jq -r '.[] | .service' | sort
    exit 1  # Exit with error code
  fi
  
  # Service exists, now get its resources
  SERVICE_URL="https://servicereference.us-east-1.amazonaws.com/v1/${SERVICE_NAME}/${SERVICE_NAME}.json"
  
  echo "Resources for $SERVICE_NAME:"
  
  # Get the service JSON
  SERVICE_JSON=$(curl -s "$SERVICE_URL")
  
  # Check if ResourceTypes exists and has keys
  RESOURCE_COUNT=$(echo "$SERVICE_JSON" | jq '.ResourceTypes | keys | length')
  
  if [ "$RESOURCE_COUNT" -gt 0 ]; then
    # List all resource types
    echo "$SERVICE_JSON" | jq -r '.ResourceTypes | keys[]'
  else
    echo "This service has no resources"
  fi
}

# Call the function with the provided service name
list_service_resource_names "$1"
