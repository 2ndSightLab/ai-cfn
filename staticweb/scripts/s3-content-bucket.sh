#!/bin/bash

# S3 bucket for website content
read -p "Deploy S3 bucket for website content? (y/n): " DEPLOY_S3_BUCKET
if [[ "$DEPLOY_S3_BUCKET" == "y" || "$DEPLOY_S3_BUCKET" == "Y" ]]; then
  read -p "S3 bucket name (default: ${DOMAIN_NAME}-content): " S3_BUCKET_NAME
  S3_BUCKET_NAME=${S3_BUCKET_NAME:-"${DOMAIN_NAME}-content"}
  
  if stack_exists $S3_WEBSITE_STACK; then
    echo "S3 website stack already exists. Updating..."
  else
    echo "Creating new S3 website stack..."
  fi
  
  echo "Deploying S3 bucket for website content..."
  aws cloudformation deploy \
    --template-file s3.yaml \
    --stack-name $S3_WEBSITE_STACK \
    --parameter-overrides \
      BucketName=$S3_BUCKET_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  # Get the S3 bucket name from the stack outputs
  S3_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_WEBSITE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" \
    --output text)
  
  # Create a sample index.html file
  read -p "Upload a sample index.html file? (y/n): " UPLOAD_SAMPLE
  if [[ "$UPLOAD_SAMPLE" == "y" || "$UPLOAD_SAMPLE" == "Y" ]]; then
    echo "Creating a sample index.html file..."
    echo "<html><head><title>Welcome to $DOMAIN_NAME</title></head><body><h1>Welcome to $DOMAIN_NAME</h1><p>Your CloudFront distribution is working!</p></body></html>" > /tmp/index.html
    
    aws s3 cp /tmp/index.html s3://$S3_BUCKET_NAME/index.html \
      --content-type "text/html" \
      --metadata-directive REPLACE
    
    echo "Sample index.html uploaded."
  fi
else
  read -p "Enter existing S3 bucket name: " S3_BUCKET_NAME
  while [[ -z "$S3_BUCKET_NAME" ]]; do
    echo "S3 bucket name cannot be empty."
    read -p "Enter existing S3 bucket name: " S3_BUCKET_NAME
  done
fi
