list_service_resource_names() {
  SERVICE_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]')

  aws cloudformation list-types --visibility PUBLIC --type RESOURCE | \
  jq -r --arg svc "$SERVICE_NAME" '
    .TypeSummaries[] 
    | select(.TypeName | startswith("AWS::" + $svc + "::")) 
    | .TypeName 
    | sub("AWS::" + $svc + "::";"")
  '
}
