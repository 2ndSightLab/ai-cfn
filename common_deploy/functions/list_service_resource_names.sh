#!/bin/bash

list_service_resource_names(){
  SERVICE_NAME="$1"

  # Fetch the service list first to get available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"

  # Use jq to iterate over the array directly and select the service by name
  SERVICE_CHECK=$(curl -s "$SERVICE_LIST_URL" | jq -r '[] | select(.name == "'"$SERVICE_NAME"'")')

  if [ -n "$SERVICE_CHECK" ]; then
    # Service exists, now get its resources
    SERVICE_URL="https://servicereference.us-east-1.amazonaws.com/v1/${SERVICE_NAME}/${SERVICE_NAME}.json"

    # Use curl to download the JSON and jq to parse it
    echo "Resources for $SERVICE_NAME:"
    curl -s "$SERVICE_URL" | jq -r '.ResourceTypes | keys[]'
  else
    echo "Service '$SERVICE_NAME' not found in the service list."
    echo "Available services:"
    # If the top-level is an array of service objects, iterate and print names
    curl -s "$SERVICE_LIST_URL" | jq -r '[] | .name' | sort
  fi
}
