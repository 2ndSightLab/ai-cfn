#!/bin/bash

delete_failed_stack_if_exists $S3_POLICY_WEBSITE_STACK
  
aws cloudformation deploy \
    --template-file cfn/s3-bucket-policy-web.yaml \
    --stack-name $S3_POLICY_WEBSITE_STACK \
    --parameter-overrides \
      BucketName=$S3_BUCKET_NAME \
      OriginAccessIdentityId=$OAI_ID \
      
    --no-fail-on-empty-changeset
    
stack_exists $S3_POLICY_WEBSITE_STACK $REGION
