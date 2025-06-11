#!/bin/bash

read -p "Deploy CloudFront security headers policy? (y/n): " DEPLOY_POLICY
if [[ "$DEPLOY_POLICY" == "y" || "$DEPLOY_POLICY" == "Y" ]]; then

  delete_failed_stack_if_exists $CLOUDFRONT_ORIGINREQUEST_POLICY_STACK $REGION

  aws cloudformation deploy \
    --template-file cfn/cloudfront-originrequestpolicy.yaml \
    --stack-name $CLOUDFRONT_ORIGINREQUEST_POLICY_STACK \
    --no-fail-on-empty-changeset
    
fi

stack_exists $CLOUDFRONT_ORIGINREQUEST_POLICY_STACK $REGION

CLOUDFRONT_ORIGIN_POLICY_ID=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_ORIGINREQUEST_POLICY_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='OriginRequestPolicyId'].OutputValue" \
    --output text)
