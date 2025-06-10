#!/bin/bash

echo "deploy-cloudfront-logs-bucket.sh"

CLOUDFRONT_LOGS_BUCKET_NAME="$STACK_NAME_PREFIX-cloudfront-logs-$BUCKET_NAME_SUFFIX"

read -p "Deploy CloudFront Logs Bucket? (y/n): " DEPLOY_CF_LOGS
if [[ "$DEPLOY_CF_LOGS" == "y" || "$DEPLOY_CF_LOGS" == "Y" ]]; then

  # Not really used - nee to fix
  read -p "CloudFront logs retention days (default: 90): " CF_LOG_RETENTION_DAYS
  CF_LOG_RETENTION_DAYS=${CF_LOG_RETENTION_DAYS:-90}
  
  delete_failed_stack_if_exists $CLOUDFRONT_LOGS_STACK $REGION
  echo "Deploying CloudFront Logs Bucket..."
  
  aws cloudformation deploy \
    --template-file cfn/s3-bucket.yaml \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --region $REGION \
    --parameter-overrides \
      BucketName=$CLOUDFRONT_LOGS_BUCKET_NAME \
    --no-fail-on-empty-changeset
    
  stack_exists $CLOUDFRONT_LOGS_STACK $REGION  
fi

CLOUDFRONT_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --query "Stacks[0].Outputs[?ExportName=='BucketName'].OutputValue" \
    --output text \
    --region $REGION)

echo "CloudFront Logs Bucket: $CLOUDFRONT_LOGS_BUCKET_NAME"
