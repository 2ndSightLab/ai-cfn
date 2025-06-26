#!/bin/bash

list_service_resource_names(){
  SERVICE_NAME="$1"

  # Fetch the service list first to get available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"

  # Use jq to iterate over the array directly and select the service by name
  # The JSON is an array at the top level, so we iterate with []
  SERVICE_CHECK=$(curl -s "$SERVICE_LIST_URL" | jq -r '[] | select(.service == "'"$SERVICE_NAME"'")')

  if [ -n "$SERVICE_CHECK" ]; then
    # Service exists, now get its resources
    SERVICE_URL="https://servicereference.us-east-1.amazonaws.com/v1/${SERVICE_NAME}/${SERVICE_NAME}.json"

    # Use curl to download the JSON and jq to parse it
    echo "Resources for $SERVICE_NAME:"
    curl -s "$SERVICE_URL" | jq -r '.ResourceTypes | keys[]'
  else
    echo "Service '$SERVICE_NAME' not found in the service list."
    echo "Available services:"
    # Iterate over the array and print the 'service' field for each object
    curl -s "$SERVICE_LIST_URL" | jq -r '[] | .service' | sort
  fi
}
