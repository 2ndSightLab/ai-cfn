#!/bin/bash -e
get_stack_name() {
    local ENV_NAME=$1
    local IDENTITY_NAME=$2
    local SERVICE=$3
    local RESOURCE=$4
    local NAME=$5

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$IDENTITY_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] ; then
        echo "Error: All parameters (ENV_NAME, USERNAME, SERVICE, RESOURCE) must be provided." >&2
        exit
    fi
    
    #validte the service is a valid AWS service
    is_valid_aws_service $SERVICE

    #validte the resource is a valid AWS service resource
    is_valid_service_resource $RESOURCE
    
    # Return the concatenated string
    echo "$ENV_NAME-$IDENTITY_NAME-$SERVICE-$RESOURCE-$NAME"
}
