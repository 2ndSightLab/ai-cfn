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

# Get instance types that meet vCPU and memory requirements
echo "Retrieving matching instance types..."
compatible_instances=$(aws ec2 describe-instance-types \
    --region $REGION \
    --filters "Name=supported-virtualization-type,Values=$virtualization_type" \
              "Name=processor-info.supported-architecture,Values=$ami_arch" \
    --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].InstanceType" \
    --output text)

# Get pricing information and filter based on max price
echo "Filtering instance types based on price..."
filtered_instances=()
for instance in $compatible_instances; do
    # Use us-east-1 region specifically for pricing API calls
    price=$(aws pricing get-products \
        --region us-east-1 \
        --service-code AmazonEC2 \
        --filters "Type=TERM_MATCH,Field=instanceType,Value=$instance" \
                  "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
                  "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
                  "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
                  "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
                  "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
        --query 'PriceList[0]' \
        --output text | jq -r '.terms.OnDemand[].priceDimensions[].pricePerUnit.USD')
    
    # Use awk for floating-point comparison instead of bc
    if (( $(awk 'BEGIN {print ("'$price'" <= "'$max_price'")}') )); then
        filtered_instances+=("$instance")
    fi
done

# Display results
echo "Matching instance types within price range:"
printf "%-20s %-10s %-15s %-10s\n" "Instance Type" "vCPUs" "Memory (MiB)" "Price/Hour"
for instance in "${filtered_instances[@]}"; do
    instance_info=$(aws ec2 describe-instance-types \
        --instance-types $instance \
        --region $REGION \
        --query 'InstanceTypes[0].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]' \
        --output text)
    
    # Use us-east-1 region specifically for pricing API calls
    price=$(aws pricing get-products \
        --region us-east-1 \
        --service-code AmazonEC2 \
        --filters "Type=TERM_MATCH,Field=instanceType,Value=$instance" \
                  "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
                  "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
                  "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
                  "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
                  "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
        --query 'PriceList[0]' \
        --output text | jq -r '.terms.OnDemand[].priceDimensions[].pricePerUnit.USD')
    
    printf "%-20s %-10s %-15s $%-10s\n" $instance_info $price
done
