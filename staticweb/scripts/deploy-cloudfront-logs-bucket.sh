#!/bin/bash

echo "deploy-cloudfront-logs-bucket.sh"


BUCKET_NAME=${BUCKET_NAME:-"${DOMAIN_NAME}-cloudfront-logs"}
S3_ACCESS_LOGS_BUCKET_NAME=${BUCKET_NAME:-"${DOMAIN_NAME}-cloudfront-s3-access-logs"}
# CloudFront Logs Bucket
read -p "Deploy CloudFront Logs Bucket? (y/n): " DEPLOY_CF_LOGS
if [[ "$DEPLOY_CF_LOGS" == "y" || "$DEPLOY_CF_LOGS" == "Y" ]]; then
  read -p "CloudFront logs retention days (default: 365): " CF_LOG_RETENTION_DAYS
  CF_LOG_RETENTION_DAYS=${CF_LOG_RETENTION_DAYS:-365}
  
  read -p "Days before transitioning to Standard-IA (default: 30): " TRANSITION_STANDARD_IA_DAYS
  TRANSITION_STANDARD_IA_DAYS=${TRANSITION_STANDARD_IA_DAYS:-30}
  
  read -p "Days before transitioning to Glacier (default: 90): " TRANSITION_GLACIER_DAYS
  TRANSITION_GLACIER_DAYS=${TRANSITION_GLACIER_DAYS:-90}

  delete_failed_stack_if_exists $CLOUDFRONT_LOGS_STACK $REGION
  echo "Deploying CloudFront Logs Bucket..."
  aws cloudformation deploy \
    --template-file cfn/s3-cloudfront-access-log-bucket.yaml \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --region $REGION \
    --parameter-overrides \
      LogRetentionDays=$CF_LOG_RETENTION_DAYS \
      TransitionToStandardIADays=$TRANSITION_STANDARD_IA_DAYS \
      TransitionToGlacierDays=$TRANSITION_GLACIER_DAYS \
      BucketName=$BUCKET_NAME \
      S3AccessLogsBucketName=$S3_ACCESS_LOGS_BUCKET_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
    
  stack_exists $CLOUDFRONT_LOGS_STACK $REGION  
  
  CLOUDFRONT_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --query "Stacks[0].Outputs[?ExportName=='${CLOUDFRONT_LOGS_STACK}-CloudFrontLogsBucketName'].OutputValue" \
    --output text
    --region $REGION)
  
  echo "CloudFront Logs Bucket: $CLOUDFRONT_LOGS_BUCKET_NAME"
else
  CLOUDFRONT_LOGS_BUCKET_NAME=""
fi
