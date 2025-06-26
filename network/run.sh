#!/bin/bash

echo "Enter the name of the environment for which you want to deploy a shared network:"
read ENV_NAME

user=$(aws sts get-caller-identity --query User.Arn --output text | cut -d '/' -f 2)

echo "Enter VPC_CIDR (e.g. 10.20.30.0/23):"
read VPC_CIDR

VPC_NAME="${ENV_NAME}-VPC"
ENABLE_DNS_SUPPORT="true"
ENABLE_DNS_HOSTNAMES="false"
TEMPLATE_FILE="cfn/vpc.yaml"
STACK_NAME="$VPC_NAME"

IGW_NAME="${ENV_NAME}-IGW"

# Display the configuration for confirmation
echo "Deploying VPC with the following configuration:"
echo "Environment: $ENV_NAME"
echo "VPC CIDR: $VPC_CIDR"
echo "VPC Name: $VPC_NAME"
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo "Internet Gateway Name: $IGW_NAME"
echo

# Deploy the CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    VpcCidrBlock="$VPC_CIDR" \
    VpcName="$VPC_NAME" \
    EnableDnsSupport="$ENABLE_DNS_SUPPORT" \
    EnableDnsHostnames="$ENABLE_DNS_HOSTNAMES"

# Check if deployment was successful
if [ $? -eq 0 ]; then
  echo "VPC deployment completed successfully!"
else
  echo "VPC deployment failed. Please check the CloudFormation events for details."
  exit 1
fi
