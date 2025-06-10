#!/bin/bash

read -p "Deploy S3 bucket policy? (y/n): " DEPLOY_POLICY
if [[ "$DEPLOY_POLICY" == "y" || "$DEPLOY_POLICY" == "Y" ]]; then

  delete_failed_stack_if_exists $S3_POLICY_WEBSITE_STACK $REGION

  if [ "$OAI_ID" == "" ]; then ACCESS_TYPE="OAC"; else ACCESS_TYPE="OAI"; fi
  
  aws cloudformation deploy \
    --template-file cfn/s3-bucket-policy-web.yaml \
    --stack-name $S3_POLICY_WEBSITE_STACK \
    --parameter-overrides \
      BucketName=$S3_BUCKET_NAME \
      OriginAccessIdentityId=$OAI_ID \
      CloudFrontDistributionID=$CLOUDFRONT_DISTRIBUTION_ID \
      AccessType=$ACCESS_TYPE \
    --no-fail-on-empty-changeset
  
fi

stack_exists $S3_POLICY_WEBSITE_STACK $REGION $REGION
  
