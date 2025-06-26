#!/bin/bash
list_service_names(){
  # Fetch the service list to get all available services
  SERVICE_LIST_URL="https://servicereference.us-east-1.amazonaws.com/v1/service-list.json"
  
  # Debug: Print the first 200 characters of the response
  echo "First 200 characters of response:"
  curl -s "$SERVICE_LIST_URL" | head -c 200
  
  echo -e "\n\nAttempting to parse as JSON:"
  # Try to get the structure of the first element
  curl -s "$SERVICE_LIST_URL" | jq '.[0]'
  
  echo -e "\n\nAttempting to extract names:"
  # Try to extract names
  curl -s "$SERVICE_LIST_URL" | jq -r '.[].name' | head -5
}
