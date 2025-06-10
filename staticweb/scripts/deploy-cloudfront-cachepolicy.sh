#!/bin/bash

read -p "Deploy S3 bucket policy? (y/n): " DEPLOY_POLICY
if [[ "$DEPLOY_POLICY" == "y" || "$DEPLOY_POLICY" == "Y" ]]; then

  delete_failed_stack_if_exists $CLOUDFRONT_CACHE_POLICY_STACK $REGION

  aws cloudformation deploy \
    --template-file cfn/cloudfront-cachedisabledpolicy.yaml \
    --stack-name $CLOUDFRONT_CACHE_POLICY_STACK \
    --no-fail-on-empty-changeset
  
fi

stack_exists $CLOUDFRONT_CACHE_POLICY_STACK $REGION
