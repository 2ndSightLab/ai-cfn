#!/bin/bash

get_current_identity_arn() {
    local arn
    arn=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve identity ARN. Check your AWS credentials and permissions." >&2
        return 1
    fi
    echo "$arn"
}

get_username_from_arn() {
    local arn=$1
    
    # Check if ARN is provided
    if [ -z "$arn" ]; then
        echo "Error: ARN must be provided." >&2
        return 1
    fi
    
    # Split the ARN into parts
    local arn_parts=(${arn//:/ })
    
    # Check if the ARN has enough parts
    if [ ${#arn_parts[@]} -lt 6 ]; then
        echo "Error: Invalid ARN format." >&2
        return 1
    fi
    
    # Get the resource type and name
    local resource_path=${arn_parts[5]}
    
    # Handle different ARN formats
    case $resource_path in
        "root")
            echo "root"
            ;;
        "user"*)
            # For IAM users: arn:aws:iam::123456789012:user/username
            local username=${arn#*:user/}
            echo "$username"
            ;;
        "role"*)
            # For IAM roles: arn:aws:iam::123456789012:role/rolename
            local rolename=${arn#*:role/}
            echo "$rolename"
            ;;
        "assumed-role"*)
            # For assumed roles: arn:aws:sts::123456789012:assumed-role/rolename/sessionname
            local role_session=${arn#*:assumed-role/}
            local rolename=${role_session%%/*}
            echo "$rolename"
            ;;
        "federated-user"*)
            # For federated users: arn:aws:sts::123456789012:federated-user/username
            local username=${arn#*:federated-user/}
            echo "$username"
            ;;
        *)
            echo "Error: Unsupported ARN type." >&2
            return 1
            ;;
    esac
}

get_stack_name() {
    local ENV_NAME=$1
    local USERNAME=$2
    local SERVICE=$3
    local RESOURCE=$4
    local NAME=$5

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$USERNAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] || [ -z "$NAME" ]; then
        echo "Error: All parameters (ENV_NAME, USERNAME, SERVICE, RESOURCE, NAME) must be provided." >&2
        return 1
    fi

    # Return the concatenated string
    echo "$ENV_NAME-$USERNAME-$SERVICE-$RESOURCE-$NAME"
}


get_resource_name() {
    local ENV_NAME=$1
    local SERVICE=$3
    local RESOURCE=$4
    local NAME=$5

    # Check if all parameters are provided
    if [ -z "$ENV_NAME" ] || [ -z "$SERVICE" ] || [ -z "$RESOURCE" ] || [ -z "$NAME" ]; then
        echo "Error: All parameters (ENV_NAME, SERVICE, RESOURCE, NAME) must be provided." >&2
        return 1
    fi

    # Return the concatenated string
    echo "$ENV_NAME-$SERVICE-$RESOURCE-$NAME"
}

is_valid_aws_service() {
    local service_name=$1
    
    # Check if service name is provided
    if [ -z "$service_name" ]; then
        echo "Error: Service name must be provided." >&2
        return 1
    fi
    
    # Fetch the list of valid AWS service names
    local aws_services=$(curl -s https://servicereference.us-east-1.amazonaws.com/v1/service-list.json | jq -r '.services[].id')
    
    # Check if curl or jq command failed
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve AWS service list." >&2
        return 1
    fi
    
    # Check if the service name is in the list
    if [[ $aws_services =~ (^|[[:space:]])$service_name($|[[:space:]]) ]]; then
        return 0  # Valid service
    else
        echo "Error: '$service_name' is not a valid AWS service." >&2
        return 1  # Invalid service
    fi
}

is_valid_service_resource() {
    local service_name=$1
    local resource_type=$2
    
    # Check if both parameters are provided
    if [ -z "$service_name" ] || [ -z "$resource_type" ]; then
        echo "Error: Both service name and resource type must be provided." >&2
        return 1
    fi
    
    # First check if the service is valid
    is_valid_aws_service "$service_name"
    if [ $? -ne 0 ]; then
        # No need to output an error message here as is_valid_aws_service already does that
        return 1
    fi
    
    # Fetch the JSON data for the service
    local json_data=$(curl -s "https://servicereference.us-east-1.amazonaws.com/v1/${service_name}/${service_name}.json")
    
    # Check if curl command failed
    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve resource information for service '$service_name'." >&2
        return 1
    fi
    
    # Check if the resource type exists in the JSON data
    if echo "$json_data" | jq -e ".ResourceTypes | has(\"$resource_type\")" > /dev/null; then
        return 0  # Valid resource type
    else
        echo "Error: Resource type '$resource_type' is not valid for service '$service_name'." >&2
        return 1  # Invalid resource type
    fi
}



