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

# Query pricing data and sort by price
echo "Querying pricing data and sorting by price..."
sorted_pricing=$(aws pricing get-products \
    --region us-east-1 \
    --service-code AmazonEC2 \
    --filters "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
              "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
              "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
              "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
              "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
    --output json | jq '.PriceList[] | 
    fromjson | 
    select(.product.attributes.operatingSystem == "Linux") | 
    {
        instanceType: .product.attributes.instanceType,
        price: (.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD)
    }' | 
    jq -s 'sort_by(.price | tonumber) | 
    map(select(.price | tonumber <= '$max_price'))')

# Check if we got any results
if [ "$(echo $sorted_pricing | jq 'length')" -eq 0 ]; then
    echo "ERROR: No instance types found within the specified price range. Please increase your maximum price or check your filters."
    exit 1
fi

# Print the sorted pricing results
echo "Sorted pricing results (lowest to highest):"
echo $sorted_pricing | jq -r '.[] | "Instance Type: \(.instanceType), Price: $\(.price)"'

# Extract just the instance types for further processing
sorted_instances=$(echo $sorted_pricing | jq -r '.[].instanceType')

# Filter for compatible instances and limit to 10 results
echo "Filtering for compatible instances..."
filtered_instances=()
count=0
total_compatible=0

for instance in $sorted_instances; do
    # Check if instance type is compatible with AMI and meets requirements
    instance_info=$(aws ec2 describe-instance-types \
        --instance-types $instance \
        --region $REGION \
        --filters "Name=supported-virtualization-type,Values=$virtualization_type" \
                  "Name=processor-info.supported-architecture,Values=$ami_arch" \
        --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
        --output text 2>/dev/null)
    
    if [ ! -z "$instance_info" ]; then
        total_compatible=$((total_compatible + 1))
        
        # Get price for this instance type from our sorted pricing data
        price=$(echo $sorted_pricing | jq -r '.[] | select(.instanceType == "'$instance'") | .price')
        
        filtered_instances+=("$instance_info $price")
        count=$((count + 1))
        
        if [ $count -eq 10 ]; then
            break
        fi
    fi
done

# Display results
echo "Matching instance types within price range (limited to 10):"
printf "%-20s %-10s %-15s %-10s\n" "Instance Type" "vCPUs" "Memory (MiB)" "Price/Hour"
for instance in "${filtered_instances[@]}"; do
    printf "%-20s %-10s %-15s $%-10s\n" $instance
done

# Alert if more than 10 compatible types were found
if [ $total_compatible -gt 10 ]; then
    echo "Note: More than 10 compatible instance types were found. Only showing the 10 lowest-priced options."
fi

