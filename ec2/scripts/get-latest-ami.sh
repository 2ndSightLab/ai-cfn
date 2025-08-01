#!/bin/bash -e

# Function to get the current AWS region
get_current_region() {
    # First try to get region from AWS CLI configuration
    local region=$(aws configure get region)
    
    # If not found in config, try to get from AWS_REGION environment variable
    if [ -z "$region" ]; then
        region=$AWS_REGION
    fi
    
    # Return the region if found, otherwise throw an error
    if [ -n "$region" ]; then
        echo "$region"
    else
        echo "Error: Could not determine AWS region from your configuration or environment." >&2
        echo "Please configure your AWS CLI with 'aws configure' or set the AWS_REGION environment variable." >&2
        exit 1
    fi
}

# Get the current region
REGION=$(get_current_region)

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

# Function to prompt user for version offset
select_version_offset() {
    echo "How many versions back from the latest do you want to use?" >&2
    echo "0 = latest (most recent)" >&2
    echo "1 = second most recent" >&2
    echo "2 = third most recent" >&2
    echo "etc..." >&2
    
    local selection
    read -p "Enter version offset (0-10): " selection
    
    # Validate input is a number between 0 and 10
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 0 ] && [ "$selection" -le 10 ]; then
        echo "$selection"
    else
        echo "Invalid selection. Please enter a number between 0 and 10." >&2
        select_version_offset
    fi
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
            echo "Usage: get_ami_id.sh [architecture] [os] [version_offset]" >&2
            echo "  architecture: x86_64, arm64" >&2
            echo "  os: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
            echo "  version_offset: 0-10 (0 = latest, 1 = second most recent, etc.)" >&2
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
            echo "Usage: get_ami_id.sh [architecture] [os] [version_offset]" >&2
            echo "  architecture: x86_64, arm64" >&2
            echo "  os: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
            echo "  version_offset: 0-10 (0 = latest, 1 = second most recent, etc.)" >&2
            exit 1
            ;;
    esac
fi

# Check if version offset was provided as argument
if [ -z "$3" ]; then
    # No version offset provided, prompt user to select
    echo "No version offset specified as argument. Interactive selection mode:" >&2
    VERSION_OFFSET=$(select_version_offset)
    echo "Selected version offset: $VERSION_OFFSET" >&2
else
    # Validate provided version offset
    if [[ "$3" =~ ^[0-9]+$ ]] && [ "$3" -ge 0 ] && [ "$3" -le 10 ]; then
        VERSION_OFFSET=$3
    else
        echo "Error: Invalid version offset '$3'. Please enter a number between 0 and 10." >&2
        echo "Usage: get_ami_id.sh [architecture] [os] [version_offset]" >&2
        echo "  architecture: x86_64, arm64" >&2
        echo "  os: al2023, amzn2, ubuntu, ubuntu-pro, rhel, sles, debian, windows" >&2
        echo "  version_offset: 0-10 (0 = latest, 1 = second most recent, etc.)" >&2
        exit 1
    fi
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
        OS_FILTER="ubuntu/"
        OS_NAME="Ubuntu"
        OWNER="099720109477" # Canonical's AWS account ID
        ;;
    ubuntu-pro)
        OS_FILTER="ubuntu-pro-server/*"
        OS_NAME="Ubuntu Pro"
        OWNER="099720109477" # Canonical's AWS account ID
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

# Search for the AMI with gp3 volume type and no product codes (to exclude marketplace images)
echo "Searching for $OS_NAME AMI in region $REGION with architecture $ARCHITECTURE and gp3 volume type..."
echo "Version offset: $VERSION_OFFSET"

AMI_ID=$(aws ec2 describe-images \
    --region $REGION \
    --owners $OWNER \
    --filters \
    "Name=name,Values=$OS_FILTER" \
    "Name=state,Values=available" \
    "Name=architecture,Values=$ARCHITECTURE" \
    "Name=block-device-mapping.volume-type,Values=gp3" \
    --query "reverse(sort_by(Images[?!not_null(ProductCodes)], &CreationDate))[$VERSION_OFFSET].ImageId" \
    --output text)
    
if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    echo "No $OS_NAME AMI found for architecture $ARCHITECTURE in region $REGION with gp3 volume type at version offset $VERSION_OFFSET."
    exit 1
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

# Get volume type information
VOLUME_TYPE=$(echo "$AMI_DETAILS" | grep -A 5 '"Ebs":' | grep '"VolumeType":' | head -1 | sed -E 's/.*"VolumeType": "([^"]+)".*/\1/')

echo "$OS_NAME AMI Details (version offset: $VERSION_OFFSET):"
echo "AMI ID: $AMI_ID"
echo "Name: $AMI_NAME"
echo "Description: $AMI_DESC"
echo "Creation Date: $AMI_DATE"
echo "Owner ID: $AMI_OWNER"
echo "Public: $AMI_PUBLIC"
echo "Architecture: $AMI_ARCH"
echo "Volume Type: $VOLUME_TYPE"
echo "Region: $REGION"
