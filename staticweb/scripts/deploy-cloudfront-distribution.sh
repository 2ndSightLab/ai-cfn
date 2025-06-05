#!/bin/bash

# CloudFront Distribution
read -p "Deploy CloudFront Distribution? (y/n): " DEPLOY_CLOUDFRONT
if [[ "$DEPLOY_CLOUDFRONT" == "y" || "$DEPLOY_CLOUDFRONT" == "Y" ]]; then
  if [[ -z "$S3_BUCKET_NAME" ]]; then
    echo "Error: S3 bucket name is required for CloudFront distribution."
    exit 1
  fi
  
  read -p "Include www subdomain? (true/false, default: true): " INCLUDE_WWW
  INCLUDE_WWW=${INCLUDE_WWW:-true}
  
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
  
  if stack_exists $CLOUDFRONT_STACK; then
    echo "CloudFront stack already exists. Updating..."
  else
    echo "Creating new CloudFront stack..."
  fi
  
  echo "Deploying CloudFront Distribution..."
  aws cloudformation deploy \
    --template-file cloudfront.yaml \
    --stack-name $CLOUDFRONT_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
      S3BucketName=$S3_BUCKET_NAME \
      S3BucketRegion=$REGION \
      AcmCertificateArn=${ACM_CERTIFICATE_ARN:-""} \
      IncludeWWW=$INCLUDE_WWW \
      DefaultRootObject=$DEFAULT_ROOT_OBJECT \
      PriceClass=$PRICE_CLASS \
      EnableLogging=$ENABLE_LOGGING \
      LoggingBucket=${CLOUDFRONT_LOGS_BUCKET_NAME:-""} \
      LoggingPrefix=$LOGGING_PREFIX \
      EnableOriginShield=$ENABLE_ORIGIN_SHIELD \
      OriginShieldRegion=$ORIGIN_SHIELD_REGION \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  # Get the CloudFront Distribution domain name
  CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='DistributionDomainName'].OutputValue" \
    --output text)
  
  echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"
