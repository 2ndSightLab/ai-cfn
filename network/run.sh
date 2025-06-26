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

