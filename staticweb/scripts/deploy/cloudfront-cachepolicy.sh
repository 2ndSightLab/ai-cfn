#!/bin/bash

echo "scripts/deploy/cloudfront-cachepolicy.sh"

read -p "Deploy CloudFront no cache policy? (y/n): " DEPLOY_POLICY
if [[ "$DEPLOY_POLICY" == "y" || "$DEPLOY_POLICY" == "Y" ]]; then

  delete_failed_stack_if_exists $CLOUDFRONT_CACHE_POLICY_STACK $REGION

  aws cloudformation deploy \
    --template-file cfn/cloudfront-cachedisabledpolicy.yaml \
    --stack-name $CLOUDFRONT_CACHE_POLICY_STACK \
    --no-fail-on-empty-changeset
    
fi

stack_exists $CLOUDFRONT_CACHE_POLICY_STACK $REGION

CLOUDFRONT_CACHE_POLICY_ID=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_CACHE_POLICY_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='CachePolicyId'].OutputValue" \
    --output text)
