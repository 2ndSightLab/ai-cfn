#!/bin/bash -e
get_stack_resource_name() {
    local ENV_NAME="$1" 
    local SERVICE="$2" 
    local RESOURCE="$3"
    local NAME="$4"

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] ; then
        echo "Error: All parameters (ENV_NAME, SERVICE, RESOURCE) must be provided." >&2
        exit
    fi

    #validte the service is a valid AWS service
    is_valid_aws_service "$SERVICE"
    
    #validte the resource is a valid AWS service resource
    is_valid_service_resource "$SERVICE" "$RESOURCE"

    ENV_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    IDENTITY_NAME=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    SERVICE=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    RESOURCE=$(echo "$4" | tr '[:upper:]' '[:lower:]')
    NAME=$(echo "$5" | tr '[:upper:]' '[:lower:]')

    # Return the concatenated string
    resource_name="$ENV_NAME-$SERVICE-$RESOURCE"

    if [ "$NAME" != "" ]; then
        resource_name="$resource_name-$NAME"
    fi

    echo $resource_name
}
