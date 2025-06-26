#!/bin/bash

#ENV_NAME and USERNAME must be set before sourcing this code

if [ "$ENV_NAME" == "" ]; then echo "variable ENV_NAME is not set which is used in the stackname and VPC NAME"; fi
if [ "$USERNAME" == "" ]; then echo "variable USERNAME is not set which is used in the stackname"; fi

VPC_NAME="$ENV_NAME-vpc"
STACK_NAME="$ENV_NAME-$USERNAME-EC2-$VPC_NAME"

echo "Enter VPC_CIDR (e.g. 10.20.30.0/23):"
read VPC_CIDR

VPC_NAME="${ENV_NAME}-vpc"
ENABLE_DNS_SUPPORT="true"
ENABLE_DNS_HOSTNAMES="false"
VPC_TEMPLATE_FILE="cfn/vpc.yaml"
VPC_STACK_NAME="$VPC_NAME"

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
