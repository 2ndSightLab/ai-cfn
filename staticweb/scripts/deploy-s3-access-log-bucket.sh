#!/bin/bash

echo "deploy-s3-access-log-bucket.sh"

BUCKET_NAME=${BUCKET_NAME:-"${DOMAIN_NAME}-s3-access-logs"}
S3_ACCESS_LOGS_BUCKET_NAME="$STACK_NAME_PREFIX-s3-logs-$BUCKET_NAME_SUFFIX"

# S3 Access Logs Bucket
read -p "Deploy S3 Access Logs Bucket? (y/n): " DEPLOY_S3_ACCESS_LOGS
if [[ "$DEPLOY_S3_ACCESS_LOGS" == "y" || "$DEPLOY_S3_ACCESS_LOGS" == "Y" ]]; then
  read -p "S3 access logs retention days (default: 90): " S3_LOG_RETENTION_DAYS
  S3_LOG_RETENTION_DAYS=${S3_LOG_RETENTION_DAYS:-90}

  delete_failed_stack_if_exists $S3_ACCESS_LOGS_STACK $REGION
  
  echo "Deploying S3 Access Logs Bucket..."
  aws cloudformation deploy \
    --template-file cfn/s3-bucket.yaml \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --region $REGION \
    --parameter-overrides \
      BucketName=$BUCKET_NAME \
      AccessControl=LogDeliveryWrite \
      VersioningStatus=Enabled \
      LifecycleRuleId=ExpireLogsRule \
      LifecycleRuleStatus=Enabled \
      LifecycleRuleExpirationDays=$S3_LOG_RETENTION_DAYS \
    --no-fail-on-empty-changeset

  stack_exists $S3_ACCESS_LOGS_STACK $REGION
  
  S3_ACCESS_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?ExportName=='${S3_ACCESS_LOGS_STACK}-S3AccessLogsBucketName'].OutputValue" \
    --output text)
  
  echo "S3 Access Logs Bucket: $S3_ACCESS_LOGS_BUCKET_NAME"
fi
