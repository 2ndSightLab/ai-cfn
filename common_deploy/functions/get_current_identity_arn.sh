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
