#!/bin/bash -e

echo "Enter the name of the environment for which you want to deploy an Internet Gateway:"
read ENV_NAME

# Get VPC ID from the previously deployed VPC stack
VPC_STACK_NAME="${ENV_NAME}-vpc"
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name "$VPC_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

if [ -z "$VPC_ID" ]; then
  echo "Error: Could not retrieve VPC ID from stack $VPC_STACK_NAME"
  exit 1
fi

IGW_NAME="${ENV_NAME}-igw"
TEMPLATE_FILE="cfn/internetgateway.yaml"
STACK_NAME="${ENV_NAME}-igw"

# Display the configuration for confirmation
echo "Deploying Internet Gateway with the following configuration:"
echo "Environment: $ENV_NAME"
echo "VPC ID: $VPC_ID"
echo "Internet Gateway Name: $IGW_NAME"
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo

# Deploy the CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    InternetGatewayName="$IGW_NAME"

# Get Internet Gateway ID from stack outputs
IGW_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='InternetGatewayId'].OutputValue" \
  --output text)

# Display the retrieved value
echo "Internet Gateway ID: $IGW_ID"

