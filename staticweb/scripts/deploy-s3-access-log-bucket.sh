#!/bin/bash

echo "deploy-s3-access-log-bucket.sh"

# Check for required variables
if [ -z "$DOMAIN_NAME" ]; then
  echo "Error: DOMAIN_NAME environment variable is not set"
  exit 1
fi

if [ -z "$STACK_NAME_PREFIX" ]; then
  echo "Error: STACK_NAME_PREFIX environment variable is not set"
  exit 1
fi

if [ -z "$BUCKET_NAME_SUFFIX" ]; then
  echo "Error: BUCKET_NAME_SUFFIX environment variable is not set"
  exit 1
fi

if [ -z "$S3_ACCESS_LOGS_STACK" ]; then
  echo "Error: S3_ACCESS_LOGS_STACK environment variable is not set"
  exit 1
fi

if [ -z "$REGION" ]; then
  echo "Error: REGION environment variable is not set"
  exit 1
fi

# Check for required functions
if ! command -v delete_failed_stack_if_exists &> /dev/null; then
  echo "Error: delete_failed_stack_if_exists function is not defined"
  exit 1
fi

if ! command -v stack_exists &> /dev/null; then
  echo "Error: stack_exists function is not defined"
  exit 1
fi

# Check if template file exists
if [ ! -f "cfn/s3-bucket.yaml" ]; then
  echo "Error: CloudFormation template file not found at cfn/s3-bucket.yaml"
  exit 1
fi

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
      BucketName=$S3_ACCESS_LOGS_BUCKET_NAME \
      AccessControl=LogDeliveryWrite \
      VersioningStatus=Enabled \
      LifecycleRuleId=ExpireLogsRule \
      LifecycleRuleStatus=Enabled \
      LifecycleRuleExpirationDays=$S3_LOG_RETENTION_DAYS \
    --no-fail-on-empty-changeset

  stack_exists $S3_ACCESS_LOGS_STACK $REGION
  
fi

S3_ACCESS_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?ExportName=='BucketName'].OutputValue" \
    --output text)
  
echo "S3 Access Logs Bucket: $S3_ACCESS_LOGS_BUCKET_NAME"
