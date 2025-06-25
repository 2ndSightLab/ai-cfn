#!/bin/bash -e

# Assume OS_NAME, AMI_ID, and REGION are already set

# Set default values
MIN_VCPU=1  # Lowest acceptable for an EC2 instance type
MIN_MEMORY=0.5  # Lowest allowed value in GiB for EC2 instance types

read -p "Enter minimum number of vCPUs [$MIN_VCPU]: " input_vcpu
min_vcpu=${input_vcpu:-$MIN_VCPU}

read -p "Enter minimum amount of memory in GiB [$MIN_MEMORY]: " input_memory
min_memory=${input_memory:-$MIN_MEMORY}

read -p "Enter maximum price per hour: " max_price

# Convert memory to MiB for EC2 API compatibility
min_memory_mib=$(awk "BEGIN {print $min_memory * 1024}")

echo "Selected parameters:"
echo "Minimum vCPUs: $min_vcpu"
echo "Minimum Memory: $min_memory_mib MiB"
echo "Maximum Price per Hour: $max_price"

# Get AMI virtualization types
virtualization_types=$(aws ec2 describe-images --image-ids $AMI_ID --region $REGION --query 'Images[0].VirtualizationType' --output text)

echo "AMI ID: $AMI_ID (Supported virtualization types: $virtualization_types)"

# Retrieve and display matching instance types in a table
echo "Retrieving matching instance types..."

aws ec2 describe-instance-types \
    --region $REGION \
    --filters "Name=vcpu-info.default-vcpus,Values=$min_vcpu-" \
              "Name=memory-info.size-in-mib,Values=$min_memory_mib-" \
              "Name=supported-virtualization-type,Values=$virtualization_types" \
    --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
    --output table
