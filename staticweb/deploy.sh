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
STACK_NAME_PREFIX=${STACK_NAME_PREFIX:-my-website}
S3_ACCESS_LOGS_STACK="${STACK_NAME_PREFIX}-s3-access-logs"
CLOUDFRONT_LOGS_STACK="${STACK_NAME_PREFIX}-cloudfront-logs"
S3_WEBSITE_STACK="${STACK_NAME_PREFIX}-s3-website"
HOSTED_ZONE_STACK="${STACK_NAME_PREFIX}-hosted-zone"
TLS_CERTIFICATE_STACK="${STACK_NAME_PREFIX}-tls-certificate"
CERT_VALIDATION_STACK="${STACK_NAME_PREFIX}-cert-validation"
DNS_RECORDS_STACK="${STACK_NAME_PREFIX}-dns-records"
CLOUDFRONT_STACK="${STACK_NAME_PREFIX}-cloudfront"

# Function to check if a CloudFormation stack exists
stack_exists() {
  local stack_name=$1
  if aws cloudformation describe-stacks --stack-name $stack_name &>/dev/null; then
    return 0  # Stack exists
  else
    return 1  # Stack does not exist
  fi
}

source ./deploy-hosted-zone.sh
source ./scripts/check-certificate-exists.sh
source ./scripts/delete-existing-certificates.sh
source ./scripts/deploy-tls-cert.sh
source ./scripts/deploy-tls-cert-validation.sh
source ./scripts/deploy-s3-content-bucket.sh
source ./scripts/deploy-s3-access-log-bucket.sh
source ./scripts/deploy-cloudfront-logs-bucket.sh
source ./scripts/deploy-cloudfront-distribution.sh
source ./scripts/deploy-validation-dns-records.sh

echo "Deployment complete!"
echo "Website URL: https://$DOMAIN_NAME"
if [[ ! -z "$CLOUDFRONT_DOMAIN" ]]; then
  echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"
fi

echo "Script execution completed."

'''
# Final certificate status check and instructions
if [[ ! -z "$ACM_CERTIFICATE_ARN" ]]; then
  FINAL_CERT_STATUS=$(aws acm describe-certificate \
    --certificate-arn $ACM_CERTIFICATE_ARN \
    --region us-east-1 \
    --query 'Certificate.Status' \
    --output text)
  
  if [[ "$FINAL_CERT_STATUS" != "ISSUED" ]]; then
    echo ""
    echo "============================================================"
    echo "IMPORTANT: Certificate Status: $FINAL_CERT_STATUS"
    echo "============================================================"
    echo "Your CloudFront distribution has been created, but the SSL/TLS certificate"
    echo "is still being validated. HTTPS access will not work until validation completes."
    echo ""
    echo "To check validation status:"
    echo "  aws acm describe-certificate --certificate-arn $ACM_CERTIFICATE_ARN --region us-east-1"
    echo ""
    echo "You can also check the status in the AWS Console:"
    echo "  https://console.aws.amazon.com/acm/home?region=us-east-1#/certificates/list"
    echo ""
    echo "Once validation is complete, your site will be accessible via HTTPS."
  else
    echo ""
    echo "Certificate is validated and active. Your site is ready to serve HTTPS traffic."
  fi
fi
'''

