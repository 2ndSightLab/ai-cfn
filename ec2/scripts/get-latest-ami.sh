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
    read -p "Enter your choice (1-2): " selection
    
    case $selection in
        1)
            echo "x86_64"
            ;;
        2)
            echo "arm64"
            ;;
        *)
            echo "Invalid selection. Please try again." >&2
            select_architecture
            ;;
    esac
}

# Function to prompt user to select operating system
select_os() {
    # Print directly to stderr to ensure visibility
    echo "Please select the operating system:" >&2
    echo "1) Amazon Linux 2023" >&2
    echo "2) Amazon Linux 2" >&2
    echo "3) Ubuntu (standard)" >&2
    echo "4) Ubuntu Pro" >&2
    echo "5) Red Hat Enterprise Linux (RHEL)" >&2
    echo "6) SUSE Linux Enterprise Server (SLES)" >&2
    echo "7) Debian" >&2
    echo "8) Windows Server" >&2
    
    local selection
    read -p "Enter your choice (1-8): " selection
    
    case $selection in
        1)
            echo "al2023"
            ;;
        2)
            echo "amzn2"
            ;;
        3)
            echo "ubuntu"
            ;;
        4)
            echo "ubuntu-pro"
            ;;
        5)
            echo "rhel"
            ;;
        6)
            echo "sles"
            ;;
        7)
            echo "debian"
            ;;
        8)
            echo "windows"
            ;;
        *)
            echo "Invalid selection. Please try again." >&2
            select_os
            ;;
    esac
}

# Check if architecture was provided as argument
if [ -z "$1" ]; then
    # No architecture provided, prompt user to select
    echo "No architecture specified as argument. Interactive selection mode:" >&2
    ARCHITECTURE=$(select_architecture)
    echo "Selected architecture: $ARCHITECTURE" >&2
else
    # Validate provided architecture
    case "$1" in
        x86_64|arm64)
            ARCHITECTURE=$1
            ;;
        *)
            echo "Error: Invalid architecture '$1'. Valid options are 'x86_64' or 'arm64'." >&2
            echo "Usage: get_ami_id.sh [architecture] [os]" >&2
            echo "  architecture: x86_64, arm64" >&2
            echo "  os: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
            exit 1
            ;;
    esac
fi

# Check if OS was provided as argument
if [ -z "$2" ]; then
    # No OS provided, prompt user to select
    echo "No OS specified as argument. Interactive selection mode:" >&2
    OS=$(select_os)
    echo "Selected OS: $OS" >&2
else
    # Validate provided OS
    case "$2" in
        al2023|amzn2|ubuntu|ubuntu-pro|rhel|sles|debian|windows)
            OS=$2
            ;;
        *)
            echo "Error: Invalid operating system '$2'." >&2
            echo "Valid options are: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
            echo "Usage: get_ami_id.sh [architecture] [os]" >&2
            echo "  architecture: x86_64, arm64" >&2
            echo "  os: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
            exit 1
            ;;
    esac
fi

# Set the appropriate filter values and owner based on OS selection
case "$OS" in
    al2023)
        OS_FILTER="al2023-ami-*"
        OS_NAME="Amazon Linux 2023"
        OWNER="amazon"
        ;;
    amzn2)
        OS_FILTER="amzn2-ami-hvm-*"
        OS_NAME="Amazon Linux 2"
        OWNER="amazon"
        ;;
    ubuntu)
        OS_FILTER="ubuntu/images/hvm-ssd/ubuntu-*-*-server-*"
        OS_NAME="Ubuntu"
        OWNER="099720109477" # Canonical's AWS account ID
        ;;
    ubuntu-pro)
        # Use multiple filters to match names starting with "ubuntu-pro/" or "ubuntu-pro-server/"
        OS_NAME="Ubuntu Pro"
        OWNER="099720109477" # Canonical's AWS account ID
        
        echo "Searching for Ubuntu Pro AMIs with names starting with 'ubuntu-pro/' or 'ubuntu-pro-server/'..."
        
        # AWS CLI doesn't support OR conditions in filters directly, so we'll need to make two separate calls
        # and combine the results
        
        # First, search for AMIs with names starting with "ubuntu-pro/"
        AMI_ID_1=$(aws ec2 describe-images \
            --region $REGION \
            --owners $OWNER \
            --filters \
            "Name=name,Values=ubuntu-pro/*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=$ARCHITECTURE" \
            --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
            --output text)
            
        # Then, search for AMIs with names starting with "ubuntu-pro-server/"
        AMI_ID_2=$(aws ec2 describe-images \
            --region $REGION \
            --owners $OWNER \
            --filters \
            "Name=name,Values=ubuntu-pro-server/*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=$ARCHITECTURE" \
            --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
            --output text)
            
        # Get the creation dates for both AMIs to determine which is newer
        if [ -n "$AMI_ID_1" ] && [ "$AMI_ID_1" != "None" ]; then
            AMI_DATE_1=$(aws ec2 describe-images \
                --region $REGION \
                --image-ids $AMI_ID_1 \
                --query 'Images[0].CreationDate' \
                --output text)
        else
            AMI_DATE_1=""
        fi
        
        if [ -n "$AMI_ID_2" ] && [ "$AMI_ID_2" != "None" ]; then
            AMI_DATE_2=$(aws ec2 describe-images \
                --region $REGION \
                --image-ids $AMI_ID_2 \
                --query 'Images[0].CreationDate' \
                --output text)
        else
            AMI_DATE_2=""
        fi
        
        # Choose the newer AMI
        if [ -z "$AMI_DATE_1" ] && [ -z "$AMI_DATE_2" ]; then
            echo "No Ubuntu Pro AMIs found with names starting with 'ubuntu-pro/' or 'ubuntu-pro-server/'."
            exit 1
        elif [ -z "$AMI_DATE_1" ]; then
            AMI_ID=$AMI_ID_2
            echo "Found Ubuntu Pro AMI with name starting with 'ubuntu-pro-server/'."
        elif [ -z "$AMI_DATE_2" ]; then
            AMI_ID=$AMI_ID_1
            echo "Found Ubuntu Pro AMI with name starting with 'ubuntu-pro/'."
        else
            # Compare dates and choose the newer one
            if [[ "$AMI_DATE_1" > "$AMI_DATE_2" ]]; then
                AMI_ID=$AMI_ID_1
                echo "Found newer Ubuntu Pro AMI with name starting with 'ubuntu-pro/'."
            else
                AMI_ID=$AMI_ID_2
                echo "Found newer Ubuntu Pro AMI with name starting with 'ubuntu-pro-server/'."
            fi
        fi
        ;;
    rhel)
        OS_FILTER="RHEL-*"
        OS_NAME="Red Hat Enterprise Linux"
        OWNER="309956199498" # Red Hat's AWS account ID
        ;;
    sles)
        OS_FILTER="suse-sles-*"
        OS_NAME="SUSE Linux Enterprise Server"
        OWNER="amazon"
        ;;
    debian)
        OS_FILTER="debian-*"
        OS_NAME="Debian"
        OWNER="136693071363" # Debian's AWS account ID
        ;;
    windows)
        OS_FILTER="Windows_Server-*"
        OS_NAME="Windows Server"
        OWNER="amazon"
        ;;
esac

# If we haven't already found an AMI (for Ubuntu Pro), search for it now
if [ -z "$AMI_ID" ]; then
    echo "Searching for latest $OS_NAME AMI in region $REGION with architecture $ARCHITECTURE..."
    
    AMI_ID=$(aws ec2 describe-images \
        --region $REGION \
        --owners $OWNER \
        --filters \
        "Name=name,Values=$OS_FILTER" \
        "Name=state,Values=available" \
        "Name=architecture,Values=$ARCHITECTURE" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text)
        
    if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
        echo "No $OS_NAME AMI found for architecture $ARCHITECTURE in region $REGION."
        exit 1
    fi
fi

# Get additional details about the AMI using JSON output format for more reliable parsing
AMI_DETAILS=$(aws ec2 describe-images \
    --region $REGION \
    --image-ids $AMI_ID \
    --output json)

# Extract individual fields using grep and sed for maximum compatibility
AMI_NAME=$(echo "$AMI_DETAILS" | grep '"Name":' | head -1 | sed -E 's/.*"Name": "([^"]+)".*/\1/')
AMI_DESC=$(echo "$AMI_DETAILS" | grep '"Description":' | head -1 | sed -E 's/.*"Description": "([^"]+)".*/\1/')
AMI_DATE=$(echo "$AMI_DETAILS" | grep '"CreationDate":' | head -1 | sed -E 's/.*"CreationDate": "([^"]+)".*/\1/')
AMI_OWNER=$(echo "$AMI_DETAILS" | grep '"OwnerId":' | head -1 | sed -E 's/.*"OwnerId": "([^"]+)".*/\1/')
AMI_PUBLIC=$(echo "$AMI_DETAILS" | grep '"Public":' | head -1 | sed -E 's/.*"Public": ([^,]+).*/\1/')
AMI_ARCH=$(echo "$AMI_DETAILS" | grep '"Architecture":' | head -1 | sed -E 's/.*"Architecture": "([^"]+)".*/\1/')

# Check if this is a marketplace image
PRODUCT_CODES=$(echo "$AMI_DETAILS" | grep -c '"ProductCodes":')
if [ "$PRODUCT_CODES" -gt 0 ] && [ "$(echo "$AMI_DETAILS" | grep -c '"ProductCodes": \[\]')" -eq 0 ]; then
    echo "Warning: This appears to be a marketplace image."
fi

echo "Latest $OS_NAME AMI Details:"
echo "AMI ID: $AMI_ID"
echo "Name: $AMI_NAME"
echo "Description: $AMI_DESC"
echo "Creation Date: $AMI_DATE"
echo "Owner ID: $AMI_OWNER"
echo "Public: $AMI_PUBLIC"
echo "Architecture: $AMI_ARCH"
echo "Region: $REGION"
