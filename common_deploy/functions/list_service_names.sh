#!/bin/bash
list_service_names(){
  # Fetch the service list to get all available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"
  
  # Use curl to download the JSON and jq to parse it
  echo "Available AWS services:"
  curl -s "$SERVICE_LIST_URL" | jq -r '.[] | .name' | sort
}
