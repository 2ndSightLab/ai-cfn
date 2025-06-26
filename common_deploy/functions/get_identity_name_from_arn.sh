#!/bin/bash
get_identity_name_from_arn() {
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
