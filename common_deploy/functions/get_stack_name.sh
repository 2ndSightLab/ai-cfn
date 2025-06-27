#!/bin/bash -e
get_stack_name() {
    local ENV_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local IDENTITY_NAME=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    local SERVICE=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    local RESOURCE=$(echo "$4" | tr '[:upper:]' '[:lower:]')
    local NAME=$(echo "$5" | tr '[:upper:]' '[:lower:]')

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$IDENTITY_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] ; then
        echo "Error: All parameters (ENV_NAME, USERNAME, SERVICE, RESOURCE) must be provided." >&2
        exit
    fi
    
    # Return the concatenated string
    echo "$ENV_NAME-$IDENTITY_NAME-$SERVICE-$RESOURCE-$NAME"
}
