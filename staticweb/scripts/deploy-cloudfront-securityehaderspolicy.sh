#!/bin/bash

read -p "Deploy CloudFront security headers policy? (y/n): " DEPLOY_POLICY
if [[ "$DEPLOY_POLICY" == "y" || "$DEPLOY_POLICY" == "Y" ]]; then

  delete_failed_stack_if_exists $CLOUDFRONT_SECURITYHEADERS_POLICY_STACK $REGION

  aws cloudformation deploy \
    --template-file cfn/cloudfront-securityheaderspolicy.yaml \
    --stack-name $CLOUDFRONT_SECURITYHEADERS_POLICY_STACK \
    --no-fail-on-empty-changeset
    
fi

stack_exists $CLOUDFRONT_SECURITYHEADERS_POLICY_STACK $REGION

CLOUDFRONT_CACHE_POLICY_ID=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_SECURITYHEADERS_POLICY_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='SecurityHeadersPolicyId'].OutputValue" \
    --output text)
