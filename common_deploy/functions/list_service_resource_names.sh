#!/bin/bash
list_service_resource_names(){
  SERVICE_NAME="$1"
  
  # Fetch the service list first to get available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"
  
  # Store the response
  RESPONSE=$(curl -s "$SERVICE_LIST_URL")
  
  # Check if the service exists in the service list
  SERVICE_CHECK=$(echo "$RESPONSE" | jq -r '.[] | select(.service == "'$SERVICE_NAME'")')
  
  if [ -n "$SERVICE_CHECK" ]; then
    # Service exists, now get its resources
    SERVICE_URL="https://servicereference.us-east-1.amazonaws.com/v1/${SERVICE_NAME}/${SERVICE_NAME}.json"
    
    # Use curl to download the JSON and jq to parse it
    echo "Resources for $SERVICE_NAME:"
    
    # Get the service JSON
    SERVICE_JSON=$(curl -s "$SERVICE_URL")
    
    # Try to get resource types, output custom message if none exist
    RESOURCES=$(echo "$SERVICE_JSON" | jq -r 'if has("ResourceTypes") and (.ResourceTypes | length > 0) then .ResourceTypes | keys[] else "This service has no resources" end')
    echo "$RESOURCES"
  else
    echo "Service '$SERVICE_NAME' not found in the service list."
    echo "Available services:"
    echo "$RESPONSE" | jq -r '.[] | .service' | sort
  fi
}
