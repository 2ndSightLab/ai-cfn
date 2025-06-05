#!/bin/bash

# TLS Certificate 
ACM_CERTIFICATE_ARN=""

# Check if any valid certificates exist
if check_certificate_exists "$DOMAIN_NAME" "us-east-1"; then
  echo "Existing certificate ARN: $ACM_CERTIFICATE_ARN"
else
  echo "No valid certificates found for $DOMAIN_NAME"
  ACM_CERTIFICATE_ARN=""
fi

# Check for existing certificates first
if check_certificate_exists "$DOMAIN_NAME" "us-east-1"; then
   echo "Certificate exists with ARN: $ACM_CERTIFICATE_ARN"
fi

read -p "Deploy TLS certificate? (y/n): " DEPLOY_CERTIFICATE
if [[ "$DEPLOY_CERTIFICATE" == "y" || "$DEPLOY_CERTIFICATE" == "Y" ]]; then
  
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
      echo "Enter hosted zone ID:"
      read HOSTED_ZONE_ID
    fi
  
    read -p "Include www subdomain in certificate? (true/false, default: true): " INCLUDE_WWW
    INCLUDE_WWW=${INCLUDE_WWW:-true}
  
    # Deploy the certificate using CloudFormation
    aws cloudformation deploy \
      --template-file cfn/tls-certificate.yaml \
      --stack-name $TLS_CERTIFICATE_STACK \
      --parameter-overrides \
        DomainName=$DOMAIN_NAME \
        IncludeWWW=$INCLUDE_WWW \
        HostedZoneId=$HOSTED_ZONE_ID \
      --capabilities CAPABILITY_IAM \
      --no-fail-on-empty-changeset
fi

# Get the certificate ARN from the stack outputs
ACM_CERTIFICATE_ARN=$(aws cloudformation describe-stacks \
      --stack-name $TLS_CERTIFICATE_STACK \
      --query "Stacks[0].Outputs[?OutputKey=='CertificateArn'].OutputValue" \
      --output text)
    
echo "Certificate requested with ARN: $ACM_CERTIFICATE_ARN"

# Check if validation is already complete
CERT_STATUS=$(aws acm describe-certificate \
      --certificate-arn $ACM_CERTIFICATE_ARN \
      --region us-east-1 \
      --query 'Certificate.Status' \
      --output text)
    
if [[ "$CERT_STATUS" == "ISSUED" ]]; then
    echo "Certificate is already validated and active."
    VALIDATION_NEEDED=false
else
    echo "Certificate exists but is not yet validated."
    VALIDATION_NEEDED=true
fi
