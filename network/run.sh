#!/bin/bash -e

echo "Enter the name of the environment for which you want to deploy a shared network:"
read ENV_NAME

user=$(aws sts get-caller-identity --query User.Arn --output text | cut -d '/' -f 2)

echo "Enter VPC_CIDR (e.g. 10.20.30.0/23):"
read VPC_CIDR

VPC_NAME="${ENV_NAME}-vpc"
ENABLE_DNS_SUPPORT="true"
ENABLE_DNS_HOSTNAMES="false"
VPC_TEMPLATE_FILE="cfn/vpc.yaml"
VPC_STACK_NAME="$VPC_NAME"

IGW_NAME="${ENV_NAME}-igw"
IGW_TEMPLATE_FILE="cfn/internetgateway.yaml"
IGW_STACK_NAME="${ENV_NAME}-igw"

# Display the VPC configuration for confirmation
echo "Deploying VPC with the following configuration:"
echo "Environment: $ENV_NAME"
echo "VPC CIDR: $VPC_CIDR"
echo "VPC Name: $VPC_NAME"
echo "Stack Name: $VPC_STACK_NAME"
echo "Template File: $VPC_TEMPLATE_FILE"
echo

# Deploy the VPC CloudFormation stack
echo "Deploying VPC CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$VPC_TEMPLATE_FILE" \
  --stack-name "$VPC_STACK_NAME" \
  --parameter-overrides \
    VpcCidrBlock="$VPC_CIDR" \
    VpcName="$VPC_NAME" \
    EnableDnsSupport="$ENABLE_DNS_SUPPORT" \
    EnableDnsHostnames="$ENABLE_DNS_HOSTNAMES"

# Get VPC ID from stack outputs
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name "$VPC_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

# Display the retrieved VPC ID
echo "VPC ID: $VPC_ID"

# Display the Internet Gateway configuration for confirmation
echo
echo "Deploying Internet Gateway with the following configuration:"
echo "Environment: $ENV_NAME"
echo "VPC ID: $VPC_ID"
echo "Internet Gateway Name: $IGW_NAME"
echo "Stack Name: $IGW_STACK_NAME"
echo "Template File: $IGW_TEMPLATE_FILE"
echo

# Deploy the Internet Gateway CloudFormation stack
echo "Deploying Internet Gateway CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$IGW_TEMPLATE_FILE" \
  --stack-name "$IGW_STACK_NAME" \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    InternetGatewayName="$IGW_NAME"

# Get Internet Gateway ID from stack outputs
IGW_ID=$(aws cloudformation describe-stacks \
  --stack-name "$IGW_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='InternetGatewayId'].OutputValue" \
  --output text)

# Display the retrieved Internet Gateway ID
echo "Internet Gateway ID: $IGW_ID"

# Define route table variables
ROUTE_TABLE_NAME="${ENV_NAME}-public-rt"
ROUTE_TABLE_TEMPLATE_FILE="cfn/routetable.yaml"
ROUTE_TABLE_STACK_NAME="${ENV_NAME}-route-table"

# Display the Route Table configuration for confirmation
echo
echo "Deploying Route Table with the following configuration:"
echo "Environment: $ENV_NAME"
echo "VPC ID: $VPC_ID"
echo "Internet Gateway ID: $IGW_ID"
echo "Route Table Name: $ROUTE_TABLE_NAME"
echo "Stack Name: $ROUTE_TABLE_STACK_NAME"
echo "Template File: $ROUTE_TABLE_TEMPLATE_FILE"
echo

# Deploy the Route Table CloudFormation stack
echo "Deploying Route Table CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$ROUTE_TABLE_TEMPLATE_FILE" \
  --stack-name "$ROUTE_TABLE_STACK_NAME" \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    InternetGatewayId="$IGW_ID" \
    RouteTableName="$ROUTE_TABLE_NAME"

# Get Route Table ID from stack outputs
ROUTE_TABLE_ID=$(aws cloudformation describe-stacks \
  --stack-name "$ROUTE_TABLE_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='RouteTableId'].OutputValue" \
  --output text)

# Display the retrieved Route Table ID
echo "Route Table ID: $ROUTE_TABLE_ID"

# Function to calculate next available /28 subnet
calculate_next_subnet() {
  local vpc_cidr=$1
  local vpc_ip=$(echo $vpc_cidr | cut -d'/' -f1)
  local vpc_prefix=$(echo $vpc_cidr | cut -d'/' -f2)
  
  # Get existing subnets in the VPC
  local existing_subnets=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].CidrBlock" \
    --output text)
  
  # Calculate the base IP of the VPC
  IFS='.' read -r -a vpc_octets <<< "$vpc_ip"
  local vpc_base_ip=$((vpc_octets[0] * 256**3 + vpc_octets[1] * 256**2 + vpc_octets[2] * 256 + vpc_octets[3]))
  
  # Calculate the number of /28 subnets possible in the VPC
  local subnet_count=$((2 ** (28 - vpc_prefix)))
  
  # Try each possible /28 subnet
  for ((i=0; i<subnet_count; i++)); do
    # Calculate the base IP for this subnet
    local subnet_base_ip=$((vpc_base_ip + i * 16))
    
    # Convert back to dotted decimal
    local o1=$((subnet_base_ip / 256**3))
    local o2=$(((subnet_base_ip % 256**3) / 256**2))
    local o3=$(((subnet_base_ip % 256**2) / 256))
    local o4=$((subnet_base_ip % 256))
    
    local candidate_subnet="$o1.$o2.$o3.$o4/28"
    
    # Check if this subnet overlaps with any existing subnet
    local overlap=false
    for existing in $existing_subnets; do
      # Simple check - if the base IPs are the same, they overlap
      if [[ "$candidate_subnet" == "$existing" ]]; then
        overlap=true
        break
      fi
    done
    
    if [[ "$overlap" == "false" ]]; then
      echo "$candidate_subnet"
      return
    fi
  done
  
  # If we get here, no available subnet was found
  echo ""
}

# Prompt for subnet parameters
echo "Enter Subnet CIDR Block (e.g. 10.0.1.0/24) or press Enter for next available /28 IP range:"
read SUBNET_CIDR

# If no CIDR is entered, calculate the next available /28
if [ -z "$SUBNET_CIDR" ]; then
  SUBNET_CIDR=$(calculate_next_subnet "$VPC_CIDR")
  if [ -z "$SUBNET_CIDR" ]; then
    echo "Error: Could not find an available /28 subnet in the VPC CIDR range."
    exit 1
  fi
  echo "Using next available subnet CIDR: $SUBNET_CIDR"
fi

echo "Enter Subnet Name:"
read SUBNET_NAME

# Check if subnet name starts with environment name prefix, if not add it
if [[ ! "$SUBNET_NAME" == "$ENV_NAME"* ]]; then
  SUBNET_NAME="${ENV_NAME}-${SUBNET_NAME}"
  echo "Subnet name updated to: $SUBNET_NAME"
fi

echo "Enter Availability Zone (leave empty for default):"
read AZ

# Use default if no AZ is entered
if [ -z "$AZ" ]; then
  # Don't include AZ parameter, let CloudFormation use the default
  AZ_PARAMETER=""
  echo "Using default Availability Zone"
else
  AZ_PARAMETER="AvailabilityZone=$AZ"
fi

echo "Map Public IP on Launch? (true/false):"
read MAP_PUBLIC_IP

SUBNET_TEMPLATE_FILE="cfn/subnet.yaml"
SUBNET_STACK_NAME="${ENV_NAME}-subnet"

# Display the subnet configuration for confirmation
echo
echo "Deploying Subnet with the following configuration:"
echo "VPC ID: $VPC_ID"
echo "Subnet CIDR: $SUBNET_CIDR"
echo "Subnet Name: $SUBNET_NAME"
if [ -z "$AZ_PARAMETER" ]; then
  echo "Availability Zone: Default"
else
  echo "Availability Zone: $AZ"
fi
echo "Map Public IP: $MAP_PUBLIC_IP"
echo "Stack Name: $SUBNET_STACK_NAME"
echo "Template File: $SUBNET_TEMPLATE_FILE"
echo

# Build parameter overrides string
PARAMETER_OVERRIDES="VpcId=$VPC_ID SubnetCidrBlock=$SUBNET_CIDR SubnetName=$SUBNET_NAME MapPublicIpOnLaunch=$MAP_PUBLIC_IP"
if [ ! -z "$AZ_PARAMETER" ]; then
  PARAMETER_OVERRIDES="$PARAMETER_OVERRIDES $AZ_PARAMETER"
fi

# Deploy the Subnet CloudFormation stack
echo "Deploying Subnet CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$SUBNET_TEMPLATE_FILE" \
  --stack-name "$SUBNET_STACK_NAME" \
  --parameter-overrides $PARAMETER_OVERRIDES

# Get Subnet ID from stack outputs
SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name "$SUBNET_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='SubnetId'].OutputValue" \
  --output text)

# Display the retrieved Subnet ID
echo "Subnet ID: $SUBNET_ID"

# Define subnet route table association variables
SUBNET_RT_ASSOC_TEMPLATE_FILE="cfn/subnetroutetableassociation.yaml"
SUBNET_RT_ASSOC_STACK_NAME="${ENV_NAME}-subnet-rt-assoc"

# Display the Subnet Route Table Association configuration for confirmation
echo
echo "Deploying Subnet Route Table Association with the following configuration:"
echo "Subnet ID: $SUBNET_ID"
echo "Route Table ID: $ROUTE_TABLE_ID"
echo "Stack Name: $SUBNET_RT_ASSOC_STACK_NAME"
echo "Template File: $SUBNET_RT_ASSOC_TEMPLATE_FILE"
echo

# Deploy the Subnet Route Table Association CloudFormation stack
echo "Deploying Subnet Route Table Association CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$SUBNET_RT_ASSOC_TEMPLATE_FILE" \
  --stack-name "$SUBNET_RT_ASSOC_STACK_NAME" \
  --parameter-overrides \
    SubnetId="$SUBNET_ID" \
    RouteTableId="$ROUTE_TABLE_ID"

# Get Association ID from stack outputs
ASSOCIATION_ID=$(aws cloudformation describe-stacks \
  --stack-name "$SUBNET_RT_ASSOC_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='AssociationId'].OutputValue" \
  --output text)

# Display the retrieved Association ID
echo "Subnet Route Table Association ID: $ASSOCIATION_ID"
