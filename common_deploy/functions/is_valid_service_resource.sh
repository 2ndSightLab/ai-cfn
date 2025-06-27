#!/bin/bash -e

is_valid_service_resource() {
  SERVICE_NAME="$1"
  RESOURCE_NAME="$2"

  RESOURCE_EXISTS=$(aws cloudformation list-types --visibility PUBLIC --type RESOURCE | \
  jq -r --arg svc "$SERVICE_NAME" --arg res "$RESOURCE_NAME" '
    .TypeSummaries[] 
    | select((.TypeName | ascii_upcase) == ("AWS::" + $svc + "::" + $res)) 
    | .TypeName
  ')

  if [ -z "$RESOURCE_EXISTS" ]; then
    echo "Error: Invalid resource name '$RESOURCE_NAME' for service '$SERVICE_NAME'"
    exit
  fi
}
