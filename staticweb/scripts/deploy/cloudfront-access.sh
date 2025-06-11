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

read -p "Use Origin Access Control (OAC) (Recommended)? (y/n): " USE_OAC
if [[ "$USE_OAC" == "y" || "$USE_OAC" == "Y" ]]; then

  read -p "Deploy OAC? (y/n): " DEPLOY_OAC
  if [[ "$DEPLOY_OAC" == "y" || "$DEPLOY_OAC" == "Y" ]]; then

    echo "Creating Origin Access Control (OAC) Stack"
    TEMPLATE_FILE="cfn/origin-access-control.yaml"
    delete_failed_stack_if_exists $OAC_STACK $REGION
  
    aws cloudformation deploy \
      --stack-name $OAC_STACK \
      --template-file $TEMPLATE_FILE \
      --parameter-overrides \
         OACName=$OAC_STACK \
         OriginType="s3" \
      --no-fail-on-empty-changeset

    stack_exists $OAC_STACK $REGION
  fi
  
  OAC_ID=$(aws cloudformation describe-stacks \
    --stack-name $OAC_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='OriginAccessControlId'].OutputValue" \
    --output text)
    
  echo "CloudFront Origin Access Control created successfully."
  echo "OAC ID: $OAC_ID"
  
else

  echo "Using OAI for CloudFront access to S3"
  
  read -p "Deploy Origin Access Identity (OAI)? (y/n): " DEPLOY_OAI
  if [[ "$DEPLOY_OAI" == "y" || "$DEPLOY_OAI" == "Y" ]]; then

    echo "Creating Origin Access Identity (OAI) Stack"
    TEMPLATE_FILE="cfn/origin-access-identity.yaml"
    delete_failed_stack_if_exists $OAI_STACK $REGION 
  
    aws cloudformation deploy \
      --stack-name $OAI_STACK \
      --template-file $TEMPLATE_FILE \
      --no-fail-on-empty-changeset

  fi
  
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

