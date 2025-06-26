#!/bin/bash -e
get_cfn_resource_name() {
    local ENV_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local SERVICE=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    local RESOURCE=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    local NAME=$(echo "$4" | tr '[:upper:]' '[:lower:]')

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] ; then
        echo "Error: All parameters (ENV_NAME, SERVICE, RESOURCE) must be provided." >&2
        exit
    fi

    #validte the service is a valid AWS service
    is_valid_aws_service "$SERVICE"
    
    #validte the resource is a valid AWS service resource
    is_valid_service_resource "$SERVICE" "$RESOURCE"

    # Return the concatenated string
    resource_name="$ENV_NAME-$SERVICE-$RESOURCE"

    if [ "$NAME" != "" ]; then
        resource_name="$resource_name-$NAME"
    fi
}
