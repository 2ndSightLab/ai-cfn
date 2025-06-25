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

# Retrieve and display matching instance types in a table
echo "Retrieving matching instance types..."

aws ec2 describe-instance-types \
    --region $REGION \
    --filters "Name=vcpu-info.default-vcpus,Values=$min_vcpu-" \
              "Name=memory-info.size-in-mib,Values=$min_memory_mib-" \
    --query "InstanceTypes[?{
        vcpu: to_number(VCpuInfo.DefaultVCpus) >= $min_vcpu,
        memory: to_number(MemoryInfo.SizeInMiB) >= $min_memory_mib
    }].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
    --output table
