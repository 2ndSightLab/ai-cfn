#!/bin/bash

TEMPLATE_FILE="origin-access-identity.yaml"

# Check if OAI_STACK is set
if [ -z "$OAI_STACK" ]; then
  echo "Error: OAI_STACK variable is not set. Please set it before running this script."
  echo "Example: export OAI_STACK=\"cloudfront-oai-stack\""
  exit 1
fi

read -p "Deploy Origin Access Identity? (y/n): " DEPLOY_OAI
if [[ "$DEPLOY_OAI" == "y" || "$DEPLOY_OAI" == "Y" ]]; then
  # Deploy the CloudFormation stack
  aws cloudformation create-stack \
    --stack-name $OAI_STACK \
    --template-body file://$TEMPLATE_FILE

  # Wait for the stack to complete
  echo "Waiting for stack $OAI_STACK to complete..."
  aws cloudformation wait stack-create-complete \
    --stack-name $OAI_STACK
fi

# Get the OAI ID from the stack outputs
OAI_ID=$(aws cloudformation describe-stacks \
  --stack-name $OAI_STACK \
  --query "Stacks[0].Outputs[?OutputKey=='OriginAccessIdentityId'].OutputValue" \
  --output text)

echo "CloudFront Origin Access Identity created successfully."
echo "OAI ID: $OAI_ID"
