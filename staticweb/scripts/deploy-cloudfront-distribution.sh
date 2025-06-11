#!/bin/bash

echo "deploy-cloudfront-distribution.sh"

# CloudFront Distribution
read -p "Deploy CloudFront Distribution? (y/n): " DEPLOY_CLOUDFRONT
if [[ "$DEPLOY_CLOUDFRONT" == "y" || "$DEPLOY_CLOUDFRONT" == "Y" ]]; then
  if [[ -z "$S3_BUCKET_NAME" ]]; then
    echo "Error: S3 bucket name is required for CloudFront distribution."
    exit 1
  fi
    
  read -p "Default root object (default: index.html): " DEFAULT_ROOT_OBJECT
  DEFAULT_ROOT_OBJECT=${DEFAULT_ROOT_OBJECT:-index.html}
  echo "Price Class options:"
  echo "  PriceClass_100: North America and Europe Only"
  echo "  PriceClass_200: North America, Europe, Asia, Middle East, and Africa"
  echo "  PriceClass_All: All CloudFront edge locations worldwide"
  read -p "Price Class (default: PriceClass_100): " PRICE_CLASS
  PRICE_CLASS=${PRICE_CLASS:-PriceClass_100}
  
  read -p "Enable CloudFront access logging? (true/false, default: true): " ENABLE_LOGGING
  ENABLE_LOGGING=${ENABLE_LOGGING:-true}
  
  read -p "CloudFront logs prefix (default: cloudfront-logs/): " LOGGING_PREFIX
  LOGGING_PREFIX=${LOGGING_PREFIX:-cloudfront-logs/}
  
  read -p "Enable Origin Shield? (true/false, default: true): " ENABLE_ORIGIN_SHIELD
  ENABLE_ORIGIN_SHIELD=${ENABLE_ORIGIN_SHIELD:-true}
  
  read -p "Origin Shield region (default: $REGION): " ORIGIN_SHIELD_REGION
  ORIGIN_SHIELD_REGION=${ORIGIN_SHIELD_REGION:-$REGION}
  delete_failed_stack_if_exists $CLOUDFRONT_STACK $REGION
  
  echo "Deploying CloudFront Distribution..."
  aws cloudformation deploy \
    --template-file cfn/cloudfront.yaml \
    --stack-name $CLOUDFRONT_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
      DomainType=$DOMAIN_TYPE \
      S3BucketName=$S3_BUCKET_NAME \
      S3BucketRegion=$REGION \
      AcmCertificateArn=${ACM_CERTIFICATE_ARN:-""} \
      DefaultRootObject=$DEFAULT_ROOT_OBJECT \
      PriceClass=$PRICE_CLASS \
      EnableLogging=$ENABLE_LOGGING \
      LoggingBucket=${CLOUDFRONT_LOGS_BUCKET_NAME:-""} \
      LoggingPrefix=$LOGGING_PREFIX \
      EnableOriginShield=$ENABLE_ORIGIN_SHIELD \
      OriginShieldRegion=$ORIGIN_SHIELD_REGION \
      SecurityPolicyID=$CLOUDFRONT_SECURITYHEADERS_POLICY_ID \
      OriginPolicyID=$CLOUDFRONT_ORIGIN_POLICY_ID \
      CachePolicyID=$CLOUDFRONT_CACHE_POLICY_ID \
    --no-fail-on-empty-changeset
  stack_exists $CLOUDFRONT_STACK $REGION
fi


# Get the CloudFront Distribution domain name
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name $CLOUDFRONT_STACK \
  --query "Stacks[0].Outputs[?OutputKey=='DistributionDomainName'].OutputValue" \
  --output text)

echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"

# Get the S3 bucket name from the stack outputs
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='DistributionId'].OutputValue" \
    --output text)
    
echo "CloudFront Distribution ID: $CLOUDFRONT_DISTRIBUTION_ID"
