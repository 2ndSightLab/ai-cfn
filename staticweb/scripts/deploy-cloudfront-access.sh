#!/bin/bash

TEMPLATE_FILE=""
OAI_ID=""
OAC_ID=""

# Check if OAI_STACK is set
if [ -z "$OAI_STACK" ]; then
  echo "Error: OAI_STACK variable is not set. Please set it before running this script."
  echo "Example: export OAI_STACK=\"cloudfront-oai-stack\""
  exit 1
fi

# Check if OAC_STACK is set
if [ -z "$OAC_STACK" ]; then
  echo "Error: OAC_STACK variable is not set. Please set it before running this script."
  echo "Example: export OAC_STACK=\"cloudfront-oac-stack\""
  exit 1
fi

read -p "Do you want to use Origin Access Control (OAC) to permit CloudFront to access the S3 bucket (Recommended)? If you do not respond y then Origin Access Identity will be used (OAI) (y/n): " DEPLOY_OAC

if [[ "$DEPLOY_OAC" == "y" || "$DEPLOY_OAC" == "Y" ]]; then

  echo "Creating Origin Access Control Stack"
  delete_stack $OAI_STACK $REGION || "Stack is in a failed state but cannot delete it.""
  TEMPLATE_FILE="cfn/origin-access-control.yaml"
  delete_failed_stack_if_exists $OAC_STACK $REGION || "Stack is in a failed state but cannot delete it.""
  
  aws cloudformation deploy \
    --stack-name $OAC_STACK \
    --template-file $TEMPLATE_FILE \
    --parameter-overrides OACName=$STACK_PREFIX OriginType=s3

  stack_exists $OAC_STACK $REGION

  OAC_ID=$(aws cloudformation describe-stacks \
    --stack-name $OAC_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='OriginAccessControlId'].OutputValue" \
    --output text)
    
  echo "CloudFront Origin Access Control created successfully."
  echo "OAC ID: $OAC_ID"
  
else

  echo "Creating Origin Access Identity Stack"
  delete_stack $OAC_STACK $REGION
  TEMPLATE_FILE="cfn/origin-access-identity.yaml"
  # Delete failed stack if it exists
  delete_failed_stack_if_exists $OAI_STACK $REGION || "Stack is in a failed state but cannot delete it.""
  
  # Deploy the CloudFormation stack
  aws cloudformation deploy \
    --stack-name $OAI_STACK \
    --template-file $TEMPLATE_FILE

  stack_exists $OAI_STACK $REGION
  
  OAI_ID=$(aws cloudformation describe-stacks \
    --stack-name $OAI_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='OriginAccessIdentityId'].OutputValue" \
    --output text)
    
  echo "OAI ID: $OAI_ID"

  S3_CANONICAL_USER_ID=$(aws cloudformation describe-stacks \
    --stack-name $OAI_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='S3CanonicalUserId'].OutputValue" \
    --output text)
  echo "S3 CANONICAL USER ID: $S3_CANONICAL_USER_ID"

fi

