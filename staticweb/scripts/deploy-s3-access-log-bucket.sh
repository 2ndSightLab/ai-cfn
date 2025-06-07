#!/bin/bash

echo "deploy-s3-access-log-bucket.sh"

# S3 Access Logs Bucket
read -p "Deploy S3 Access Logs Bucket? (y/n): " DEPLOY_S3_ACCESS_LOGS
if [[ "$DEPLOY_S3_ACCESS_LOGS" == "y" || "$DEPLOY_S3_ACCESS_LOGS" == "Y" ]]; then
  read -p "S3 access logs retention days (default: 90): " S3_LOG_RETENTION_DAYS
  S3_LOG_RETENTION_DAYS=${S3_LOG_RETENTION_DAYS:-90}

  S3_ACCESS_LOGS_BUCKET_NAME="$STACK_NAME_PREFIX-s3-logs-$BUCKET_NAMIE_SUFFIX"

  delete_failed_stack_if_exists $S3_ACCESS_LOGS_STACK $REGION
  
  echo "Deploying S3 Access Logs Bucket..."
  aws cloudformation deploy \
    --template-file cfn/s3-access-log-bucket.yaml \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --region $REGION \
    --bucket-name S3_ACCESS_LOGS_BUCKET_NAME \
    --parameter-overrides \
      LogRetentionDays=$S3_LOG_RETENTION_DAYS \
      BucketNameSuffix=$BUCKET_NAME_SUFFIX \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

   stack_exists $S3_ACCESS_LOGS_STACK $REGION
  
  S3_ACCESS_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?ExportName=='${S3_ACCESS_LOGS_STACK}-S3AccessLogsBucketName'].OutputValue" \
    --output text)
  
  echo "S3 Access Logs Bucket: $S3_ACCESS_LOGS_BUCKET_NAME"
else
  S3_ACCESS_LOGS_BUCKET_NAME=""
fi
