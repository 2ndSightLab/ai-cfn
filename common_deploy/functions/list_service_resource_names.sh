#!/bin/bash
list_service_resource_names(){
  SERVICE_NAME="$1"
  
  # Fetch the service list first to get available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"
  
  # First, let's check the actual structure of the response
  RESPONSE=$(curl -s "$SERVICE_LIST_URL")
  
  # Check if the service exists in the service list
  # Modified jq query to handle the actual structure (likely a flat array)
  SERVICE_CHECK=$(echo "$RESPONSE" | jq -r '.[] | select(.name == "'$SERVICE_NAME'")' 2>/dev/null)
  
  if [ -n "$SERVICE_CHECK" ]; then
    # Service exists, now get its resources
    SERVICE_URL="https://servicereference.us-east-1.amazonaws.com/v1/${SERVICE_NAME}/${SERVICE_NAME}.json"
    
    # Use curl to download the JSON and jq to parse it
    echo "Resources for $SERVICE_NAME:"
    curl -s "$SERVICE_URL" | jq -r '.ResourceTypes | keys[]'
  else
    echo "Service '$SERVICE_NAME' not found in the service list."
    echo "Available services:"
    # Modified to handle the actual structure
    echo "$RESPONSE" | jq -r '.[] | .name' 2>/dev/null | sort
    
    # If the above fails, try to determine the actual structure
    if [ $? -ne 0 ]; then
      echo "Could not parse service list. JSON structure may have changed."
      echo "First few lines of the response:"
      echo "$RESPONSE" | head -n 10
    fi
  fi
}
