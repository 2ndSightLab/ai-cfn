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
S3_WEBSITE_STACK="${STACK_NAME_PREFIX}-s3-website"
HOSTED_ZONE_STACK="${STACK_NAME_PREFIX}-hosted-zone"
TLS_CERTIFICATE_STACK="${STACK_NAME_PREFIX}-tls-certificate"
CERT_VALIDATION_STACK="${STACK_NAME_PREFIX}-cert-validation"
DNS_RECORDS_STACK="${STACK_NAME_PREFIX}-dns-records"
CLOUDFRONT_STACK="${STACK_NAME_PREFIX}-cloudfront"

# Domain name
read -p "Domain name (e.g., example.com): " DOMAIN_NAME
while [[ -z "$DOMAIN_NAME" ]]; do
  echo "Domain name cannot be empty."
  read -p "Domain name (e.g., example.com): " DOMAIN_NAME
done

# Function to check if a CloudFormation stack exists
stack_exists() {
  local stack_name=$1
  if aws cloudformation describe-stacks --stack-name $stack_name &>/dev/null; then
    return 0  # Stack exists
  else
    return 1  # Stack does not exist
  fi
}

# Route 53 Hosted Zone
read -p "Deploy Route 53 hosted zone? (y/n): " DEPLOY_HOSTED_ZONE
if [[ "$DEPLOY_HOSTED_ZONE" == "y" || "$DEPLOY_HOSTED_ZONE" == "Y" ]]; then
  if stack_exists $HOSTED_ZONE_STACK; then
    echo "Hosted zone stack already exists. Updating..."
  else
    echo "Creating new hosted zone stack..."
  fi
  
  echo "Deploying Route 53 hosted zone for $DOMAIN_NAME..."
  aws cloudformation deploy \
    --template-file hosted-zone.yaml \
    --stack-name $HOSTED_ZONE_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  # Get the Hosted Zone ID from the stack outputs
  HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='HostedZoneId'].OutputValue" \
    --output text)
  
  NAME_SERVERS=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='NameServers'].OutputValue" \
    --output text)
  
  echo "Hosted Zone ID: $HOSTED_ZONE_ID"
  echo "IMPORTANT: Update your domain's name servers with your registrar to point to:"
  echo "$NAME_SERVERS"
  echo "DNS propagation may take up to 48 hours."
else
  read -p "Enter existing Route 53 Hosted Zone ID (leave empty to skip): " HOSTED_ZONE_ID
fi

# TLS Certificate - COMPLETELY REVISED VERSION
ACM_CERTIFICATE_ARN=""

# Function to check if a certificate exists and is valid
check_certificate_exists() {
  local domain=$1
  local region=${2:-us-east-1}
  
  echo "Thoroughly checking for existing certificates for $domain..."
  
  # List only ISSUED or PENDING_VALIDATION certificates
  local valid_certs=$(aws acm list-certificates \
    --region $region \
    --certificate-statuses "ISSUED" "PENDING_VALIDATION" \
    --query "CertificateSummaryList[?DomainName=='$domain'].CertificateArn" \
    --output text)
  
  if [[ -z "$valid_certs" ]]; then
    echo "No valid certificates found for $domain"
    return 1
  fi
  
  echo "Found potentially valid certificate ARNs: $valid_certs"
  
  # Check each certificate
  for cert_arn in $valid_certs; do
    echo "Checking certificate: $cert_arn"
    
    local describe_result
    if ! describe_result=$(aws acm describe-certificate --certificate-arn "$cert_arn" --region $region); then
      echo "Certificate $cert_arn cannot be described - might be in an inconsistent state"
      continue
    fi
    
    local status=$(echo "$describe_result" | jq -r '.Certificate.Status')
    
    echo "Certificate status: $status"
    
    # Only consider ISSUED or PENDING_VALIDATION certificates as valid
    if [[ "$status" == "ISSUED" || "$status" == "PENDING_VALIDATION" ]]; then
      echo "Found valid certificate: $cert_arn with status: $status"
      ACM_CERTIFICATE_ARN=$cert_arn
      return 0
    fi
  done
  
  echo "No valid certificates found for $domain"
  return 1
}

# Ask if user wants to force delete any existing certificates
read -p "Force delete any existing certificates for $DOMAIN_NAME? (y/n): " FORCE_DELETE_CERT
if [[ "$FORCE_DELETE_CERT" == "y" || "$FORCE_DELETE_CERT" == "Y" ]]; then
  echo "Searching for certificates to delete..."
  
  # List all certificates for the domain, including expired and failed ones
  CERT_ARNS=$(aws acm list-certificates \
    --region us-east-1 \
    --include-expired \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" \
    --output text)
  
  if [[ -z "$CERT_ARNS" ]]; then
    echo "No certificates found for $DOMAIN_NAME"
  else
    echo "Found certificates: $CERT_ARNS"
    
    # Try to delete each certificate
    for CERT_ARN in $CERT_ARNS; do
      echo "Attempting to delete certificate: $CERT_ARN"
      if aws acm delete-certificate --certificate-arn $CERT_ARN --region us-east-1; then
        echo "Successfully deleted certificate: $CERT_ARN"
      else
        echo "Failed to delete certificate: $CERT_ARN"
        echo "This certificate might be in use by another AWS service."
        echo "Please check the AWS Console and manually remove any resources using this certificate."
      fi
    done
  fi
fi

# Now check if any valid certificates exist
if check_certificate_exists "$DOMAIN_NAME" "us-east-1"; then
  echo "Using existing certificate with ARN: $ACM_CERTIFICATE_ARN"
else
  echo "No valid certificates found for $DOMAIN_NAME"
  ACM_CERTIFICATE_ARN=""
fi

read -p "Deploy TLS certificate? (y/n): " DEPLOY_CERTIFICATE
if [[ "$DEPLOY_CERTIFICATE" == "y" || "$DEPLOY_CERTIFICATE" == "Y" ]]; then
  if [[ -z "$HOSTED_ZONE_ID" ]]; then
    echo "Error: A Route 53 hosted zone is required for DNS validation."
    exit 1
  fi
  
  read -p "Include www subdomain in certificate? (true/false, default: true): " INCLUDE_WWW
  INCLUDE_WWW=${INCLUDE_WWW:-true}
  
  if [[ ! -z "$ACM_CERTIFICATE_ARN" ]]; then
    read -p "Use existing certificate? (y/n): " USE_EXISTING_CERT
    if [[ "$USE_EXISTING_CERT" != "y" && "$USE_EXISTING_CERT" != "Y" ]]; then
      ACM_CERTIFICATE_ARN=""
    fi
  fi
  
  if [[ -z "$ACM_CERTIFICATE_ARN" ]]; then
    echo "Requesting ACM certificate for $DOMAIN_NAME..."
    
    # Create certificate request
    CERTIFICATE_ARN=$(aws acm request-certificate \
      --domain-name $DOMAIN_NAME \
      --validation-method DNS \
      --subject-alternative-names $([ "$INCLUDE_WWW" == "true" ] && echo "www.$DOMAIN_NAME" || echo "") \
      --region us-east-1 \
      --query 'CertificateArn' \
      --output text)
    
    echo "Certificate requested with ARN: $CERTIFICATE_ARN"
    echo "Waiting for certificate details..."
    sleep 10
    
    # Get validation record details for the main domain
    VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
      --certificate-arn $CERTIFICATE_ARN \
      --region us-east-1 \
      --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN_NAME'].ResourceRecord.Name" \
      --output text)
    
    VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
      --certificate-arn $CERTIFICATE_ARN \
      --region us-east-1 \
      --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN_NAME'].ResourceRecord.Value" \
      --output text)
    
    # Get validation record details for the www subdomain if included
    if [[ "$INCLUDE_WWW" == "true" ]]; then
      WWW_VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
        --certificate-arn $CERTIFICATE_ARN \
        --region us-east-1 \
        --query "Certificate.DomainValidationOptions[?DomainName=='www.$DOMAIN_NAME'].ResourceRecord.Name" \
        --output text)
      
      WWW_VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
        --certificate-arn $CERTIFICATE_ARN \
        --region us-east-1 \
        --query "Certificate.DomainValidationOptions[?DomainName=='www.$DOMAIN_NAME'].ResourceRecord.Value" \
        --output text)
    else
      WWW_VALIDATION_RECORD_NAME=""
      WWW_VALIDATION_RECORD_VALUE=""
    fi
    
    # Deploy validation records
    if stack_exists $CERT_VALIDATION_STACK; then
      echo "Certificate validation stack already exists. Updating..."
    else
      echo "Creating new certificate validation stack..."
    fi
    
    echo "Deploying certificate validation DNS records..."
    aws cloudformation deploy \
      --template-file certificate-validation.yaml \
      --stack-name $CERT_VALIDATION_STACK \
      --parameter-overrides \
        HostedZoneId=$HOSTED_ZONE_ID \
        DomainName=$DOMAIN_NAME \
        ValidationDomain1RecordName="$VALIDATION_RECORD_NAME" \
        ValidationDomain1RecordValue="$VALIDATION_RECORD_VALUE" \
        IncludeWWW=$INCLUDE_WWW \
        ValidationDomain2RecordName="$WWW_VALIDATION_RECORD_NAME" \
        ValidationDomain2RecordValue="$WWW_VALIDATION_RECORD_VALUE" \
      --capabilities CAPABILITY_IAM \
      --no-fail-on-empty-changeset
    
    echo "Certificate validation records created. Validation in progress..."
    
    ACM_CERTIFICATE_ARN=$CERTIFICATE_ARN
  fi
  
  echo "============================================================"
  echo "IMPORTANT: Certificate validation is now in progress"
  echo "============================================================"
  echo "Would you like to wait for certificate validation to complete before continuing?"
  echo "This may take several minutes (typically 15-30 minutes, sometimes longer)."
  read -p "Wait for validation? (y/n): " WAIT_FOR_VALIDATION
  
  if [[ "$WAIT_FOR_VALIDATION" == "y" || "$WAIT_FOR_VALIDATION" == "Y" ]]; then
    echo "Waiting for certificate validation to complete..."
    echo "This may take several minutes. You'll see updates every 30 seconds."
    echo "Press Ctrl+C to cancel waiting (the certificate will still be validated eventually)."
    
    while true; do
      CERT_STATUS=$(aws acm describe-certificate \
        --certificate-arn $ACM_CERTIFICATE_ARN \
        --region us-east-1 \
        --query 'Certificate.Status' \
        --output text)
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Certificate status: $CERT_STATUS"
      
      if [[ "$CERT_STATUS" == "ISSUED" ]]; then
        echo "Certificate validation complete! Proceeding with deployment."
        break
      elif [[ "$CERT_STATUS" == "FAILED" ]]; then
        echo "Certificate validation failed. Please check the AWS console for details."
        echo "You may need to request a new certificate."
        read -p "Continue with deployment anyway? (y/n): " CONTINUE_ANYWAY
        if [[ "$CONTINUE_ANYWAY" != "y" && "$CONTINUE_ANYWAY" != "Y" ]]; then
          echo "Exiting script. Please fix certificate issues and try again."
          exit 1
        fi
        break
      fi
      
      sleep 30
    done
  else
    echo "Continuing without waiting for certificate validation."
    echo "Note: Your CloudFront distribution will not serve HTTPS traffic until validation completes."
  fi
else
  read -p "Enter existing ACM certificate ARN (leave empty to skip): " ACM_CERTIFICATE_ARN
fi

# S3 bucket for website content
read -p "Deploy S3 bucket for website content? (y/n): " DEPLOY_S3_BUCKET
if [[ "$DEPLOY_S3_BUCKET" == "y" || "$DEPLOY_S3_BUCKET" == "Y" ]]; then
  read -p "S3 bucket name (default: ${DOMAIN_NAME}-content): " S3_BUCKET_NAME
  S3_BUCKET_NAME=${S3_BUCKET_NAME:-"${DOMAIN_NAME}-content"}
  
  if stack_exists $S3_WEBSITE_STACK; then
    echo "S3 website stack already exists. Updating..."
  else
    echo "Creating new S3 website stack..."
  fi
  
  echo "Deploying S3 bucket for website content..."
  aws cloudformation deploy \
    --template-file s3.yaml \
    --stack-name $S3_WEBSITE_STACK \
    --parameter-overrides \
      BucketName=$S3_BUCKET_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  # Get the S3 bucket name from the stack outputs
  S3_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $S3_WEBSITE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" \
    --output text)
  
  # Create a sample index.html file
  read -p "Upload a sample index.html file? (y/n): " UPLOAD_SAMPLE
  if [[ "$UPLOAD_SAMPLE" == "y" || "$UPLOAD_SAMPLE" == "Y" ]]; then
    echo "Creating a sample index.html file..."
    echo "<html><head><title>Welcome to $DOMAIN_NAME</title></head><body><h1>Welcome to $DOMAIN_NAME</h1><p>Your CloudFront distribution is working!</p></body></html>" > /tmp/index.html
    
    aws s3 cp /tmp/index.html s3://$S3_BUCKET_NAME/index.html \
      --content-type "text/html" \
      --metadata-directive REPLACE
    
    echo "Sample index.html uploaded."
  fi
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
  
  if stack_exists $S3_ACCESS_LOGS_STACK; then
    echo "S3 access logs stack already exists. Updating..."
  else
    echo "Creating new S3 access logs stack..."
  fi
  
  echo "Deploying S3 Access Logs Bucket..."
  aws cloudformation deploy \
    --template-file s3-access-log-bucket.yaml \
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
  
  if stack_exists $CLOUDFRONT_LOGS_STACK; then
    echo "CloudFront logs stack already exists. Updating..."
  else
    echo "Creating new CloudFront logs stack..."
  fi
  
  echo "Deploying CloudFront Logs Bucket..."
  aws cloudformation deploy \
    --template-file s3-cloudfront-access-log-bucket.yaml \
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
  
  # Create DNS records if we have a hosted zone
  if [[ ! -z "$HOSTED_ZONE_ID" && ! -z "$CLOUDFRONT_DOMAIN" ]]; then
    read -p "Create DNS records pointing to CloudFront? (y/n): " CREATE_DNS
    if [[ "$CREATE_DNS" == "y" || "$CREATE_DNS" == "Y" ]]; then
      # First check if the certificate is validated
      if [[ ! -z "$ACM_CERTIFICATE_ARN" ]]; then
        echo "Checking certificate validation status..."
        
        CERT_STATUS=$(aws acm describe-certificate \
          --certificate-arn $ACM_CERTIFICATE_ARN \
          --region us-east-1 \
          --query 'Certificate.Status' \
          --output text)
        
        if [[ "$CERT_STATUS" != "ISSUED" ]]; then
          echo "============================================================"
          echo "IMPORTANT: Your certificate is not yet validated (Status: $CERT_STATUS)"
          echo "============================================================"
          echo "To complete the validation process:"
          echo "1. The DNS validation records have been created in your Route 53 hosted zone"
          echo "2. Wait for DNS propagation (can take 15-30 minutes, sometimes longer)"
          echo "3. ACM will automatically validate your certificate once propagation is complete"
          echo ""
          echo "Would you like to wait for certificate validation to complete before continuing?"
          read -p "Wait for validation? (y/n): " WAIT_FOR_VALIDATION
          
          if [[ "$WAIT_FOR_VALIDATION" == "y" || "$WAIT_FOR_VALIDATION" == "Y" ]]; then
            echo "Waiting for certificate validation to complete..."
            echo "This may take several minutes. You'll see updates every 30 seconds."
            echo "Press Ctrl+C to cancel waiting (the certificate will still be validated eventually)."
            
            while true; do
              CERT_STATUS=$(aws acm describe-certificate \
                --certificate-arn $ACM_CERTIFICATE_ARN \
                --region us-east-1 \
                --query 'Certificate.Status' \
                --output text)
              
              echo "$(date '+%Y-%m-%d %H:%M:%S') - Certificate status: $CERT_STATUS"
              
              if [[ "$CERT_STATUS" == "ISSUED" ]]; then
                echo "Certificate validation complete! Proceeding with DNS record creation."
                break
              elif [[ "$CERT_STATUS" == "FAILED" ]]; then
                echo "Certificate validation failed. Please check the AWS console for details."
                echo "You may need to request a new certificate."
                read -p "Continue with DNS record creation anyway? (y/n): " CONTINUE_ANYWAY
                if [[ "$CONTINUE_ANYWAY" != "y" && "$CONTINUE_ANYWAY" != "Y" ]]; then
                  echo "Exiting script. Please fix certificate issues and try again."
                  exit 1
                fi
                break
              fi
              
              sleep 30
            done
          else
            echo "Continuing without waiting for certificate validation."
            echo "Note: Your CloudFront distribution will not serve HTTPS traffic until validation completes."
          fi
        else
          echo "Certificate is already validated. Proceeding with DNS record creation."
        fi
      fi
      
      if stack_exists $DNS_RECORDS_STACK; then
        echo "DNS records stack already exists. Updating..."
      else
        echo "Creating new DNS records stack..."
      fi
      
      echo "Creating Route 53 records using CloudFormation..."
      aws cloudformation deploy \
        --template-file dns-records.yaml \
        --stack-name $DNS_RECORDS_STACK \
        --parameter-overrides \
          DomainName=$DOMAIN_NAME \
          HostedZoneId=$HOSTED_ZONE_ID \
          CloudFrontDomainName=$CLOUDFRONT_DOMAIN \
          IncludeWWW=$INCLUDE_WWW \
        --capabilities CAPABILITY_IAM \
        --no-fail-on-empty-changeset
      
      echo "DNS records created successfully."
    fi
  fi
fi

echo "Deployment complete!"
echo "Website URL: https://$DOMAIN_NAME"
if [[ ! -z "$CLOUDFRONT_DOMAIN" ]]; then
  echo "CloudFront Distribution Domain: $CLOUDFRONT_DOMAIN"
fi

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

echo "Script execution completed."
