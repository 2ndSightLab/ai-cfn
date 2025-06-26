#!/bin/bash
list_service_resource_names() {
  SERVICE_NAME="$1"
  
  aws cloudformation list-types --visibility PUBLIC --type RESOURCE | jq -r '.TypeSummaries[] | select(.TypeName | startswith("AWS::$SERVICE_NAME::")) | .TypeName | sub("AWS::$SERVICE_NAME::";"")' 

}
