#!/bin/bash

# Function to get the current AWS region
get_current_region() {
    # First try to get region from AWS CLI configuration
    local region=$(aws configure get region)
    
    # If not found in config, try to get from AWS_REGION environment variable
    if [ -z "$region" ]; then
        region=$AWS_REGION
    fi
    
    # Return the region if found
    if [ -n "$region" ]; then
        echo "$region"
    else
        echo ""
    fi
}

# Get the current region
REGION=$(get_current_region)

# Check if region is valid
if [ -z "$REGION" ]; then
    echo "Error: Could not determine AWS region from your configuration or environment."
    echo "Please configure your AWS CLI with 'aws configure' or set the AWS_REGION environment variable."
    exit 1
fi

# Function to prompt user to select architecture
select_architecture() {
    # Print directly to stderr to ensure visibility
    echo "Please select the CPU architecture:" >&2
    echo "1) x86_64 (Intel/AMD 64-bit)" >&2
    echo "2) arm64 (ARM 64-bit, e.g., AWS Graviton)" >&2
    
    local selection
    read -p "Enter your choice (1-2): "
