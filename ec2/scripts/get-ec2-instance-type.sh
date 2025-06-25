#!/bin/bash -e

# Assume OS_NAME, AMI_ID, and REGION are already set

# Set default values
MIN_VCPU=1
MIN_MEMORY=0.5

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

# Get AMI details
echo "Getting AMI details for $AMI_ID..."
ami_arch=$(aws ec2 describe-images --image-ids $AMI_ID --region $REGION --query 'Images[0].Architecture' --output text)
virtualization_type=$(aws ec2 describe-images --image-ids $AMI_ID --region $REGION --query 'Images[0].VirtualizationType' --output text)

echo "AMI ID: $AMI_ID (Architecture: $ami_arch, Virtualization: $virtualization_type)"

# Retrieve and display matching instance types in a table
echo "Retrieving matching instance types..."

# Use a simpler approach without complex filters
aws ec2 describe-instance-types \
    --region $REGION \
    --filters "Name=supported-virtualization-type,Values=$virtualization_type" \
              "Name=processor-info.supported-architecture,Values=$ami_arch" \
    --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
    --output table

