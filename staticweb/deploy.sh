#!/bin/bash
set -e

# Generate a unique suffix for bucket names
BUCKET_NAME_SUFFIX=$(date +%Y%m%d%H%M%S)

echo "===== AWS CloudFront Website Deployment Script ====="

# AWS Region
read -p "AWS Region (default: us-east-1): " REGION
REGION=${REGION:-us-east-1}
export AWS_DEFAULT_REGION=$REGION

# Stack names
read -p "Stack name prefix (default: my-website): " STACK_NAME_PREFIX
STACK_NAME_PREFIX=${STACK_NAME_PREFIX:-my-website}
S3_ACCESS_LOGS_STACK="${STACK_NAME_PREFIX}-s3-access-logs"
CLOUDFRONT_LOGS_STACK="${STACK_NAME_PREFIX}-cloudfront-logs"
CLOUDFRONT_STACK="${STACK_NAME_PREFIX}-cloudfront"

# Domain name
read -p "Domain name (e.g., example.com): " DOMAIN_NAME
while [[ -z "$DOMAIN_NAME" ]]; do
  echo "Domain name cannot be empty."
  read -p "Domain name (e.g., example.com): " DOMAIN_NAME
done

# Route 53 Hosted Zone
read -p "Create Route 53 hosted zone? (y/n): " CREATE_HOSTED_ZONE
if [[ "$CREATE_HOSTED_ZONE" == "y" || "$CREATE_HOSTED_ZONE" == "Y" ]]; then
  echo "Creating Route 53 hosted zone for $DOMAIN_NAME..."
  HOSTED_ZONE_RESULT=$(aws route53 create-hosted-zone \
    --name $DOMAIN_NAME \
    --caller-reference "$(date +%Y%m%d%H%M%S)" \
    --hosted-zone-config Comment="Created by CloudFront deployment script")
  
  HOSTED_ZONE_ID=$(echo $HOSTED_ZONE_RESULT | jq -r '.HostedZone.Id' | sed 's/\/hostedzone\///')
  NAME_SERVERS=$(echo $HOSTED_ZONE_RESULT | jq -r '.DelegationSet.NameServers[]' | tr '\n' ' ')
  
  echo "Hosted Zone created with ID: $HOSTED_ZONE_ID"
  echo "IMPORTANT: Update your domain's name servers with your registrar to point to:"
  echo "$NAME_SERVERS"
else
  read -p "Enter existing Route 53 Hosted Zone ID (leave empty to skip): " HOSTED_ZONE_ID
fi

# ACM Certificate
read -p "Create ACM certificate? (y/n): " CREATE_CERTIFICATE
if [[ "$CREATE_CERTIFICATE" == "y" || "$CREATE_CERTIFICATE" == "Y" ]]; then
  if [[ -z "$HOSTED_ZONE_ID" ]]; then
    echo "Error: A Route 53 hosted zone is required for DNS validation."
    exit 1
  fi
  
  echo "Requesting ACM certificate for $DOMAIN_NAME and www.$DOMAIN_NAME..."
  CERTIFICATE_ARN=$(aws acm request-certificate \
    --domain-name $DOMAIN_NAME \
    --validation-method DNS \
    --subject-alternative-names www.$DOMAIN_NAME \
    --region us-east-1 \
    --query 'CertificateArn' \
    --output text)
  
  echo "Certificate requested with ARN: $CERTIFICATE_ARN"
  echo "Waiting for certificate details..."
  sleep 10
  
  # Get and create DNS validation records
  VALIDATION_RECORDS=$(aws acm describe-certificate \
    --certificate-arn $CERTIFICATE_ARN \
    --region us-east-1 \
    --query 'Certificate.DomainValidationOptions[].ResourceRecord')
  
  echo "Creating DNS validation records..."
  for i in $(seq 0 $(echo $VALIDATION_RECORDS | jq 'length - 1')); do
    RECORD_NAME=$(echo $VALIDATION_RECORDS | jq -r ".[$i].Name")
    RECORD_VALUE=$(echo $VALIDATION_RECORDS | jq -r ".[$i].Value")
    RECORD_TYPE=$(echo $VALIDATION_RECORDS | jq -r ".[$i].Type")
    
    aws route53 change-resource-record-sets \
      --hosted-zone-id $HOSTED_ZONE_ID \
      --change-batch '{
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
              "Name": "'$RECORD_NAME'",
              "Type": "'$RECORD_TYPE'",
              "TTL": 300,
              "ResourceRecords": [
                {
                  "Value": "'$RECORD_VALUE'"
                }
              ]
            }
          }
        ]
      }'
  done
  
  echo "DNS validation records created. Certificate validation in progress..."
  ACM_CERTIFICATE_ARN=$CERTIFICATE_ARN
else
  read -p "Enter existing ACM certificate ARN (leave empty to skip): " ACM_CERTIFICATE_ARN
fi

# S3 bucket for website content
read -p "Create S3 bucket for website content? (y/n): " CREATE_S3_BUCKET
if [[ "$CREATE_S3_BUCKET" == "y" || "$CREATE_S3_BUCKET" == "Y" ]]; then
  read -p "S3 bucket name (default: ${DOMAIN_NAME}-content): " S3_BUCKET_NAME
  S3_BUCKET_NAME=${S3_BUCKET_NAME:-"${DOMAIN_NAME}-content"}
  
  echo "Creating S3 bucket: $S3_BUCKET_NAME..."
  aws s3api create-bucket \
    --bucket $S3_BUCKET_NAME \
    --region $REGION \
    $(if [[ "$REGION" != "us-east-1" ]]; then echo "--create-bucket-configuration LocationConstraint=$REGION"; fi)
  
  # Configure bucket properties
  aws s3api put-public-access-block \
    --bucket $S3_BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  
  aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET_NAME \
    --versioning-configuration Status=Enabled
  
  aws s3api put-bucket-encryption \
    --bucket $S3_BUCKET_NAME \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          },
          "BucketKeyEnabled": true
        }
      ]
    }'
  
  # Create a sample index.html file
  echo "Creating a sample index.html file..."
  echo "<html><head><title>Welcome to $DOMAIN_NAME</title></head><body><h1>Welcome to $DOMAIN_NAME</h1><p>Your CloudFront distribution is working!</p></body></html>" > /tmp/index.html
  
  aws s3 cp /tmp/index.html s3://$S3_BUCKET_NAME/index.html \
    --content-type "text/html" \
    --metadata-directive REPLACE
else
  read -p "Enter existing S3 bucket name: " S3_BUCKET_NAME
  while [[ -z "$S3_BUCKET_NAME" ]]; do
    echo "S3 bucket name cannot be empty."
    read -p "Enter existing S3 bucket name: " S3_BUCKET_NAME
  done
fi

# S3 Access Logs Bucket
read -p "Deploy S3 Access Logs Bucket? (y/n): " DEPLOY_S3_ACCESS_LOGS
if [[ "$DEPLOY_S3_ACCESS_LOGS" == "y" || "$DEPLOY_S3_ACCESS_LOGS" == "Y" ]]; then
  read -p "S3 access logs retention days (default: 90): " S3_LOG_RETENTION_DAYS
  S3_LOG_RETENTION_DAYS=${S3_LOG_RETENTION_DAYS:-90}
  
  echo "Deploying S3 Access Logs Bucket..."
  aws cloudformation deploy \
    --template-file s3-access-logs.yaml \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --parameter-overrides \
      LogRetentionDays=$S3_LOG_RETENTION_DAYS \
      BucketNameSuffix=$BUCKET_NAME_SUFFIX \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  S3_ACCESS_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_ACCESS_LOGS_STACK \
    --query "Stacks[0].Outputs[?ExportName=='${S3_ACCESS_LOGS_STACK}-S3AccessLogsBucketName'].OutputValue" \
    --output text)
  
  echo "S3 Access Logs Bucket: $S3_ACCESS_LOGS_BUCKET_NAME"
else
  S3_ACCESS_LOGS_BUCKET_NAME=""
fi

# CloudFront Logs Bucket
read -p "Deploy CloudFront Logs Bucket? (y/n): " DEPLOY_CF_LOGS
if [[ "$DEPLOY_CF_LOGS" == "y" || "$DEPLOY_CF_LOGS" == "Y" ]]; then
  read -p "CloudFront logs retention days (default: 365): " CF_LOG_RETENTION_DAYS
  CF_LOG_RETENTION_DAYS=${CF_LOG_RETENTION_DAYS:-365}
  
  read -p "Days before transitioning to Standard-IA (default: 30): " TRANSITION_STANDARD_IA_DAYS
  TRANSITION_STANDARD_IA_DAYS=${TRANSITION_STANDARD_IA_DAYS:-30}
  
  read -p "Days before transitioning to Glacier (default: 90): " TRANSITION_GLACIER_DAYS
  TRANSITION_GLACIER_DAYS=${TRANSITION_GLACIER_DAYS:-90}
  
  echo "Deploying CloudFront Logs Bucket..."
  aws cloudformation deploy \
    --template-file cloudfront-logs.yaml \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --parameter-overrides \
      LogRetentionDays=$CF_LOG_RETENTION_DAYS \
      TransitionToStandardIADays=$TRANSITION_STANDARD_IA_DAYS \
      TransitionToGlacierDays=$TRANSITION_GLACIER_DAYS \
      BucketNameSuffix=$BUCKET_NAME_SUFFIX \
      S3AccessLogsBucketName=$S3_ACCESS_LOGS_BUCKET_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  CLOUDFRONT_LOGS_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $CLOUDFRONT_LOGS_STACK \
    --query "Stacks[0].Outputs[?ExportName=='${CLOUDFRONT_LOGS_STACK}-CloudFrontLogsBucketName'].OutputValue" \
    --output text)
  
  echo "CloudFront Logs Bucket: $CLOUDFRONT_LOGS_BUCKET_NAME"
else
  CLOUDFRONT_LOGS_BUCKET_NAME=""
fi

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
  
  # Create DNS records if we have a hosted zone
  if [[ ! -z "$HOSTED_ZONE_ID" ]]; then
    read -p "Create DNS records pointing to CloudFront? (y/n): " CREATE_DNS
    if [[ "$CREATE_DNS" == "y" || "$CREATE_DNS" == "Y" ]]; then
      echo "Creating Route 53 records..."
      aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch '{
          "Changes": [
            {
              "Action": "UPSERT",
              "ResourceRecordSet": {
                "Name": "'$DOMAIN_NAME'",
                "Type": "A",
                "AliasTarget": {
                  "HostedZoneId": "Z2FDTNDATAQYW2",
                  "DNSName": "'$CLOUDFRONT_DOMAIN'",
                  "EvaluateTargetHealth": false
                }
              }
            },
            {
              "Action": "UPSERT",
              "ResourceRecordSet": {
                "Name": "www.'$DOMAIN_NAME'",
                "Type": "A",
                "AliasTarget": {
                  "HostedZoneId": "Z2FDTNDATAQYW2",
                  "DNSName": "'$CLOUDFRONT_DOMAIN'",
                  "EvaluateTargetHealth": false
                }
              }
            }
          ]
        }'
      
      echo "DNS records created successfully."
    fi
  fi
fi

echo "Deployment complete!"
echo "Website URL: https://$DOMAIN_NAME"
if [[ ! -z "$CLOUDFRONT_DOMAIN" ]]; then
  echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"
fi

echo "Script execution completed."

