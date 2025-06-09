#!/bin/bash

TEMPLATE_FILE="cfn/origin-access-identity.yaml"
OAI_ID=""

# Check if OAI_STACK is set
if [ -z "$OAI_STACK" ]; then
  echo "Error: OAI_STACK variable is not set. Please set it before running this script."
  echo "Example: export OAI_STACK=\"cloudfront-oai-stack\""
  exit 1
fi

read -p "Do you want to use an Origin Access Identity (OAI) in your S3 bucket policy instead of Origin Access Control (OAC)? OAC is the default and recommended by AWS. (y/n): " DEPLOY_OAI
if [[ "$DEPLOY_OAI" == "y" || "$DEPLOY_OAI" == "Y" ]]; then
  # Delete failed stack if it exists
  delete_failed_stack_if_exists $OAI_STACK
  
  # Deploy the CloudFormation stack
  aws cloudformation create-stack \
    --stack-name $OAI_STACK \
    --template-body file://$TEMPLATE_FILE

  stack_exists $OAI_STACK
else
  # Check if the stack exists
  if aws cloudformation describe-stacks --stack-name $OAI_STACK &>/dev/null; then
    # Delete the stack
    echo "Deleting stack $OAI_STACK..."
    aws cloudformation delete-stack --stack-name $OAI_STACK

    # Wait for the stack deletion to complete
    echo "Waiting for stack $OAI_STACK deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name $OAI_STACK

    echo "Stack $OAI_STACK has been deleted successfully."
  fi
fi

# Get the OAI ID from the stack outputs if the stack exists
if aws cloudformation describe-stacks --stack-name $OAI_STACK &>/dev/null; then
  OAI_ID=$(aws cloudformation describe-stacks \
    --stack-name $OAI_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='OriginAccessIdentityId'].OutputValue" \
    --output text)

  echo "CloudFront Origin Access Identity created successfully."
  echo "OAI ID: $OAI_ID"
fi
