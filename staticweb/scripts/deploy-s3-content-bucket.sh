#!/bin/bash

echo "deploy-s3-content-bucket.sh"

# S3 bucket for website content
read -p "Deploy S3 bucket for website content? (y/n): " DEPLOY_S3_BUCKET
if [[ "$DEPLOY_S3_BUCKET" == "y" || "$DEPLOY_S3_BUCKET" == "Y" ]]; then
  S3_BUCKET_NAME=${S3_BUCKET_NAME:-"${DOMAIN_NAME}-content"}
  read -p "S3 bucket name: ${DOMAIN_NAME}-content. Enter to continue or enter a new bucket name: " S3_BUCKET_NAME

  delete_failed_stack_if_exists $S3_WEBSITE_STACK $REGION
  
  echo "Deploying S3 bucket: $S3_BUCKET_NAME for website content..."
  aws cloudformation deploy \
    --template-file cfn/s3-bucket.yaml \
    --stack-name $S3_WEBSITE_STACK \
    --parameter-overrides \
      BucketName=$S3_BUCKET_NAME \
      DeletionPolicy=Retain \
    --no-fail-on-empty-changeset

  stack_exists $S3_WEBSITE_STACK $REGION
  
fi

# Get the S3 bucket name from the stack outputs
S3_BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name $S3_WEBSITE_STACK \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)

# Create a sample index.html file
read -p "Upload a sample index.html and 404.html file? (y/n): " UPLOAD_SAMPLE
  if [[ "$UPLOAD_SAMPLE" == "y" || "$UPLOAD_SAMPLE" == "Y" ]]; then
    echo "Creating a sample index.html file..."
    echo "<html><head><title>Welcome to $DOMAIN_NAME</title></head><body><h1>Welcome to $DOMAIN_NAME</h1><p>Your CloudFront distribution is working!</p></body></html>" > /tmp/index.html
    
    aws s3 cp /tmp/index.html s3://$S3_BUCKET_NAME/index.html \
      --content-type "text/html" \
      --metadata-directive REPLACE
    
    echo "Sample index.html uploaded."

    echo "Creating a sample 404.html file..."
    echo "<html><head><title>Not Found. Sorry :-(</title></head><body><h1>Not Found. Sorry :-(</h1><p>That page wasn't found.</p></body></html>" > /tmp/404.html
    
    aws s3 cp /tmp/404.html s3://$S3_BUCKET_NAME/404.html \
      --content-type "text/html" \
      --metadata-directive REPLACE
    
    echo "Sample 404.html uploaded."
  fi
  
