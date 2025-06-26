#!/bin/bash
is_valid_service_resource() {
  SERVICE_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  RESOURCE_NAME=$(echo "$2" | tr '[:lower:]' '[:upper:]')

  RESOURCE_EXISTS=$(aws cloudformation list-types --visibility PUBLIC --type RESOURCE | \
  jq -r --arg svc "$SERVICE_NAME" --arg res "$RESOURCE_NAME" '
    .TypeSummaries[] 
    | select((.TypeName | ascii_upcase) == ("AWS::" + $svc + "::" + $res)) 
    | .TypeName
  ')

  if [ -z "$RESOURCE_EXISTS" ]; then
    echo "Error: Invalid resource name '$RESOURCE_NAME' for service '$SERVICE_NAME'"
    return 1
  else
    echo "Valid resource name: $RESOURCE_NAME for service $SERVICE_NAME"
    return 0
  fi
}
