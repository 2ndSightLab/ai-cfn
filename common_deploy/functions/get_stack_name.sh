#!/bin/bash
get_stack_name() {
    local ENV_NAME=$1
    local IDENTITY_NAME=$2
    local SERVICE=$3
    local RESOURCE=$4
    local NAME=$5

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$IDENTITY_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] || [ -z "$NAME" ]; then
        echo "Error: All parameters (ENV_NAME, USERNAME, SERVICE, RESOURCE, NAME) must be provided." >&2
        return 1
    fi

    # Return the concatenated string
    echo "$ENV_NAME-$IDENTITY_NAME-$SERVICE-$RESOURCE-$NAME"
}
