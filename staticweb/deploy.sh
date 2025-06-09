#!/bin/bash -e

echo "===== AWS CloudFront Website Deployment Script ====="

# Generate a unique suffix for bucket names
BUCKET_NAME_SUFFIX=$(date +%Y%m%d%H%M%S)

# AWS Region
read -p "AWS Region (default: us-east-1): " REGION
REGION=${REGION:-us-east-1}
export AWS_DEFAULT_REGION=$REGION

# Stack names
read -p "Stack name prefix (default: my-website): " STACK_NAME_PREFIX
if [[ $STACK_NAME_PREFIX =~ ^[0-9] ]]; then
   STACK_NAME_PREFIX="s-$STACK_NAME_PREFIX"
fi

STACK_NAME_PREFIX=${STACK_NAME_PREFIX:-my-website}
S3_ACCESS_LOGS_STACK="${STACK_NAME_PREFIX}-s3-access-logs"
CLOUDFRONT_LOGS_STACK="${STACK_NAME_PREFIX}-cloudfront-logs"
S3_WEBSITE_STACK="${STACK_NAME_PREFIX}-s3-website"
S3_POLICY_WEBSITE_STACK="${STACK_NAME_PREFIX}-s3-bucketpolicy-website"
HOSTED_ZONE_STACK="${STACK_NAME_PREFIX}-hosted-zone"
TLS_CERTIFICATE_STACK="${STACK_NAME_PREFIX}-tls-certificate"
CERT_VALIDATION_STACK="${STACK_NAME_PREFIX}-cert-validation"
DNS_RECORDS_STACK="${STACK_NAME_PREFIX}-dns-records"
CLOUDFRONT_STACK="${STACK_NAME_PREFIX}-cloudfront"
OAI_STACK="${STACK_NAME_PREFIX}-origin-access-identity"


source ./scripts/stack-exists.sh
source ./scripts/delete-failed-stack-if-exists.sh
source ./scripts/deploy-hosted-zone.sh
source ./scripts/check-certificate-exists.sh
source ./scripts/delete-existing-certificates.sh
source ./scripts/deploy-tls-cert.sh
source ./scripts/deploy-s3-access-log-bucket.sh
source ./scripts/deploy-cloudfront-logs-bucket.sh
source ./scripts/origin-access-identity.sh
source ./scripts/deploy-s3-content-bucket.sh
source ./scripts/deploy-cloudfront-distribution.sh


echo "Deployment complete!"
echo "Website URL: https://$DOMAIN_NAME"
if [[ ! -z "$CLOUDFRONT_DOMAIN" ]]; then
  echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"
fi


