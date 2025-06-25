#!/bin/bash -e

# Initialize INSTANCE_TYPE variable
INSTANCE_TYPE=""

# Function to validate numeric input
validate_numeric() {
    local input=$1
    local min=$2
    local name=$3
    
    # Check if input is a valid number (including formats like .5)
    if ! [[ $input =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "Error: $name must be a number"
        return 1
    fi
    
    # Check if input is greater than or equal to minimum
    if (( $(echo "$input < $min" | bc -l) )); then
        echo "Error: $name must be at least $min"
        return 1
    fi
    
    return 0
}

while true; do  # Main loop to allow restarting the query
    # Assume AMI_ID and REGION are already set
    
    # Verify AMI_ID and REGION are set
    if [ -z "$AMI_ID" ] || [ -z "$REGION" ]; then
        echo "Error: AMI_ID and REGION environment variables must be set"
        exit 1
    fi
    
    # Sanitize inputs
    if ! [[ $AMI_ID =~ ^ami-[a-zA-Z0-9]+$ ]]; then
        echo "Error: Invalid AMI ID format"
        exit 1
    fi
    
    if ! [[ $REGION =~ ^[a-z]+-[a-z]+-[0-9]+$ ]]; then
        echo "Error: Invalid region format"
        exit 1
    fi

    # Set default values
    MIN_VCPU=1
    MIN_MEMORY=0.5

    # Get and validate vCPU input
    while true; do
        read -p "Enter minimum number of vCPUs [$MIN_VCPU]: " input_vcpu
        input_vcpu=${input_vcpu:-$MIN_VCPU}
        
        if validate_numeric "$input_vcpu" "$MIN_VCPU" "vCPUs"; then
            min_vcpu=$input_vcpu
            break
        fi
    done

    # Get and validate memory input
    while true; do
        read -p "Enter minimum amount of memory in GiB [$MIN_MEMORY]: " input_memory
        input_memory=${input_memory:-$MIN_MEMORY}
        
        if validate_numeric "$input_memory" "$MIN_MEMORY" "Memory"; then
            min_memory=$input_memory
            break
        fi
    done

    # Get and validate price input
    while true; do
        read -p "Enter maximum price per hour: " max_price
        
        if validate_numeric "$max_price" "0" "Price"; then
            break
        fi
    done

    # Convert memory to MiB for EC2 API compatibility
    min_memory_mib=$(awk "BEGIN {print $min_memory * 1024}")

    echo "Selected parameters:"
    echo "Minimum vCPUs: $min_vcpu"
    echo "Minimum Memory: $min_memory GiB ($min_memory_mib MiB)"
    echo "Maximum Price per Hour: $max_price"

    # Get AMI details - combine into a single API call
    echo "Getting AMI details for $AMI_ID..."
    ami_info=$(aws ec2 describe-images --image-ids "$AMI_ID" --region "$REGION" --query 'Images[0].[Architecture,VirtualizationType]' --output text 2>&1)
    
    # Check for errors in AMI lookup
    if [ $? -ne 0 ]; then
        echo "Error retrieving AMI details: $ami_info"
        exit 1
    fi
    
    ami_arch=$(echo "$ami_info" | cut -d' ' -f1)
    virtualization_type=$(echo "$ami_info" | cut -d' ' -f2)

    echo "AMI ID: $AMI_ID (Architecture: $ami_arch, Virtualization: $virtualization_type)"

    # Get available instance types in the region first to narrow down our search
    echo "Getting available instance types in $REGION..."
    available_types=$(aws ec2 describe-instance-type-offerings \
        --location-type region \
        --region "$REGION" \
        --filters "Name=instance-type,Values=*" \
        --query 'InstanceTypeOfferings[].InstanceType' \
        --output text 2>&1)
        
    # Check for errors in instance type lookup
    if [ $? -ne 0 ]; then
        echo "Error retrieving instance types: $available_types"
        exit 1
    fi

    # Query pricing data with more specific filters
    echo "Querying pricing data and sorting by price..."
    pricing_result=$(aws pricing get-products \
        --region us-east-1 \
        --service-code AmazonEC2 \
        --filters "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
                "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
                "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
                "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
                "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
        --output json 2>&1)
        
    # Check for errors in pricing lookup
    if [ $? -ne 0 ]; then
        echo "Error retrieving pricing data: $pricing_result"
        exit 1
    fi
    
    sorted_pricing=$(echo "$pricing_result" | jq '.PriceList[] | 
        fromjson | 
        select(.product.attributes.operatingSystem == "Linux") | 
        {
            instanceType: .product.attributes.instanceType,
            price: (.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD)
        }' | 
        jq -s 'map(select((.price | tonumber > 0) and (.price | tonumber <= '$max_price'))) | sort_by(.price | tonumber)')

    # Check if we got any results
    if [ "$(echo "$sorted_pricing" | jq 'length')" -eq 0 ]; then
        echo "ERROR: No instance types found within the specified price range. Please increase your maximum price or check your filters."
        read -p "Press Enter to run a new query..." dummy
        continue  # Start over
    fi

    # Print the sorted pricing results
    echo "Sorted pricing results (lowest to highest):"
    echo "$sorted_pricing" | jq -r '.[] | "Instance Type: \(.instanceType), Price: $\(.price)"'

    # Extract just the instance types for further processing
    sorted_instances=$(echo "$sorted_pricing" | jq -r '.[].instanceType')

    # Get instance details in bulk for better performance
    echo "Getting instance type details..."
    
    # Create a temporary file for instance types
    temp_file=$(mktemp)
    echo "$sorted_instances" > "$temp_file"
    
    # Read instance types in batches to avoid command line length limits
    filtered_instances=()
    count=0
    total_compatible=0
    
    # Process in batches of 20 instances
    while read -r batch; do
        # Convert batch to array
        IFS=' ' read -r -a instance_array <<< "$batch"
        
        # Skip empty batches
        if [ ${#instance_array[@]} -eq 0 ]; then
            continue
        fi
        
        # Build instance type argument safely
        instance_args=()
        for inst in "${instance_array[@]}"; do
            # Validate instance type format
            if [[ "$inst" =~ ^[a-z][0-9][a-z]?\.[a-z0-9]+$ ]]; then
                instance_args+=("$inst")
            fi
        done
        
        # Skip if no valid instances in batch
        if [ ${#instance_args[@]} -eq 0 ]; then
            continue
        fi
        
        # Get instance details in bulk
        instance_details=$(aws ec2 describe-instance-types \
            --instance-types "${instance_args[@]}" \
            --region "$REGION" \
            --filters "Name=supported-virtualization-type,Values=$virtualization_type" \
                     "Name=processor-info.supported-architecture,Values=$ami_arch" \
            --query "InstanceTypes[?VCpuInfo.DefaultVCpus >= \`$min_vcpu\` && MemoryInfo.SizeInMiB >= \`$min_memory_mib\`].[InstanceType, VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]" \
            --output json 2>&1)
            
        # Check for errors in instance details lookup
        if [ $? -ne 0 ]; then
            echo "Warning: Error retrieving instance details: $instance_details"
            continue
        fi
        
        # Process the bulk results
        while IFS= read -r instance_info; do
            # Skip empty lines
            if [ -z "$instance_info" ] || [ "$instance_info" = "null" ]; then
                continue
            fi
            
            instance_type=$(echo "$instance_info" | jq -r '.[0]')
            vcpus=$(echo "$instance_info" | jq -r '.[1]')
            memory_mib=$(echo "$instance_info" | jq -r '.[2]')
            
            # Get price for this instance type from our sorted pricing data
            price=$(echo "$sorted_pricing" | jq -r --arg instance "$instance_type" '.[] | select(.instanceType == $instance) | .price')
            
            if [ ! -z "$price" ] && [ "$price" != "null" ]; then
                filtered_instances+=("$instance_type $vcpus $memory_mib $price")
                count=$((count + 1))
                total_compatible=$((total_compatible + 1))
                
                if [ $count -eq 10 ]; then
                    break 2
                fi
            fi
        done < <(echo "$instance_details" | jq -c '.[]')
        
    done < <(xargs -n 20 < "$temp_file")
    
    # Clean up temporary file
    rm -f "$temp_file"

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
            # Validate instance type format
            if ! [[ "$input_type" =~ ^[a-z][0-9][a-z]?\.[a-z0-9]+$ ]]; then
                echo "Invalid instance type format. Please try again."
                continue
            fi
            
            # Check if the selected type is in the list
            found=0
            for instance in "${filtered_instances[@]}"; do
                instance_type=$(echo "$instance" | awk '{print $1}')
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
