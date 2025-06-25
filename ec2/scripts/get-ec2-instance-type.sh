#!/bin/bash -e

# Initialize INSTANCE_TYPE variable
INSTANCE_TYPE=""

while true; do  # Main loop to allow restarting the query
    # Assume AMI_ID and REGION are already set

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

    # Get AMI details - combine into a single API call
    echo "Getting AMI details for $AMI_ID..."
    ami_info=$(aws ec2 describe-images --image-ids $AMI_ID --region $REGION --query 'Images[0].[Architecture,VirtualizationType]' --output text)
    ami_arch=$(echo $ami_info | cut -d' ' -f1)
    virtualization_type=$(echo $ami_info | cut -d' ' -f2)

    echo "AMI ID: $AMI_ID (Architecture: $ami_arch, Virtualization: $virtualization_type)"

    # Get available instance types in the region first to narrow down our search
    echo "Getting available instance types in $REGION..."
    available_types=$(aws ec2 describe-instance-type-offerings \
        --location-type region \
        --region $REGION \
        --filters "Name=instance-type,Values=*" \
        --query 'InstanceTypeOfferings[].InstanceType' \
        --output text)

    # Query pricing data with more specific filters
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
        jq -s 'map(select((.price | tonumber > 0) and (.price | tonumber <= '$max_price'))) | sort_by(.price | tonumber)')

    # Check if we got any results
    if [ "$(echo $sorted_pricing | jq 'length')" -eq 0 ]; then
        echo "ERROR: No instance types found within the specified price range. Please increase your maximum price or check your filters."
        read -p "Press Enter to run a new query..." dummy
        continue  # Start over
    fi

    # Print the sorted pricing results
    echo "Sorted pricing results (lowest to highest):"
    echo $sorted_pricing | jq -r '.[] | "Instance Type: \(.instanceType), Price: $\(.price)"'

    # Extract just the instance types for further processing
    sorted_instances=$(echo $sorted_pricing | jq -r '.[].instanceType')

    # Get instance details in bulk for better performance
    echo "Getting instance type details..."
    # Create a comma-separated list of the first 100 instance types (to avoid API limits)
    instance_list=$(echo $sorted_instances | tr ' ' '\n' | head -100 | tr '\n' ',' | sed 's/,$//')
    
    # Get instance details in bulk
    instance_details=$(aws ec2 describe-instance-types \
        --instance-types $(echo $instance_list | tr ',' ' ') \
        --region $REGION \
        --filters "Name=supported-virtualization-type,Values=$virtualization_type" \
                 "Name=processor-info.supported-architecture,Values=$ami_arch" \
        --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
        --output json)

    # Filter for compatible instances and limit to 10 results
    echo "Filtering for compatible instances..."
    filtered_instances=()
    count=0
    
    # Process the bulk results
    while IFS= read -r instance_info; do
        instance_type=$(echo $instance_info | jq -r '.[0]')
        vcpus=$(echo $instance_info | jq -r '.[1]')
        memory_mib=$(echo $instance_info | jq -r '.[2]')
        
        # Get price for this instance type from our sorted pricing data
        price=$(echo $sorted_pricing | jq -r --arg instance "$instance_type" '.[] | select(.instanceType == $instance) | .price')
        
        if [ ! -z "$price" ]; then
            filtered_instances+=("$instance_type $vcpus $memory_mib $price")
            count=$((count + 1))
            
            if [ $count -eq 10 ]; then
                break
            fi
        fi
    done < <(echo $instance_details | jq -c '.[]')

    # Display results
    echo "Matching instance types within price range (limited to 10):"
    printf "%-20s %-10s %-15s %-10s\n" "Instance Type" "vCPUs" "Memory (GiB)" "Price/Hour"
    for instance in "${filtered_instances[@]}"; do
        # Split the instance data
        read -r inst_type vcpus memory_mib price <<< "$instance"
        
        # Convert memory from MiB to GiB
        memory_gib=$(awk "BEGIN {printf \"%.1f\", $memory_mib / 1024}")
        
        printf "%-20s %-10s %-15s $%-10s\n" "$inst_type" "$vcpus" "$memory_gib" "$price"
    done

    # Alert if more than 10 compatible types were found
    total_compatible=$(echo $instance_details | jq 'length')
    if [ $total_compatible -gt 10 ]; then
        echo "Note: More than 10 compatible instance types were found. Only showing the 10 lowest-priced options."
    fi

    # Inner loop for instance type selection
    while true; do
        echo ""
        read -p "Enter an instance type from the list above or press Enter to run a new query: " input_type
        
        if [ -z "$input_type" ]; then
            echo "Starting a new query..."
            break  # Break out of the inner loop to restart the query
        else
            # Check if the selected type is in the list
            found=0
            for instance in "${filtered_instances[@]}"; do
                instance_type=$(echo $instance | awk '{print $1}')
                if [ "$instance_type" == "$input_type" ]; then
                    found=1
                    INSTANCE_TYPE="$input_type"  # Set the global INSTANCE_TYPE variable
                    break
                fi
            done
            
            if [ $found -eq 1 ]; then
                echo "You selected: $INSTANCE_TYPE"
                break 2  # Break out of both loops
            else
                echo "Invalid instance type. Please select from the list or press Enter to run a new query."
                # Continue in the inner loop to allow re-entry
            fi
        fi
    done
done

echo "Script completed with instance type: $INSTANCE_TYPE"

