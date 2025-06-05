#!/bin/bash -e

# TLS Certificate 
ACM_CERTIFICATE_ARN=""

# Check if any valid certificates exist
if check_certificate_exists "$DOMAIN_NAME" "us-east-1"; then
  echo "Existing certificate ARN: $ACM_CERTIFICATE_ARN"
else
  echo "No valid certificates found for $DOMAIN_NAME"
  ACM_CERTIFICATE_ARN=""
fi

read -p "Deploy TLS certificate? (y/n): " DEPLOY_CERTIFICATE
if [[ "$DEPLOY_CERTIFICATE" == "y" || "$DEPLOY_CERTIFICATE" == "Y" ]]; then
  
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
      echo "Enter hosted zone ID:"
      read HOSTED_ZONE_ID
    fi
  
    # Ask for certificate type
    echo "Select certificate type:"
    echo "1) Basic (domain only)"
    echo "2) WWW (domain + www subdomain)"
    echo "3) Wildcard (domain + *.domain)"
    echo "4) Custom subdomains"
    read -p "Enter your choice (1-4) [2]: " CERT_TYPE_CHOICE
    CERT_TYPE_CHOICE=${CERT_TYPE_CHOICE:-2}
    
    case $CERT_TYPE_CHOICE in
        1) CERT_TYPE="Basic" ;;
        2) CERT_TYPE="WWW" ;;
        3) CERT_TYPE="Wildcard" ;;
        4) 
            CERT_TYPE="CustomSubdomains"
            echo ""
            echo "Enter fully qualified subdomains, separated by commas"
            echo "Example: api.${DOMAIN_NAME},blog.${DOMAIN_NAME},shop.${DOMAIN_NAME}"
            read -p "Subdomains: " CUSTOM_SUBDOMAINS
            ;;
        *) 
            echo "Invalid choice. Defaulting to WWW certificate."
            CERT_TYPE="WWW"
            ;;
    esac
    
    # Ask for validation method
    echo "Select validation method:"
    echo "1) DNS validation (recommended)"
    echo "2) Email validation"
    read -p "Enter your choice (1-2) [1]: " VALIDATION_CHOICE
    VALIDATION_CHOICE=${VALIDATION_CHOICE:-1}
    
    if [ "$VALIDATION_CHOICE" == "1" ]; then
        VALIDATION_METHOD="DNS"
    else
        VALIDATION_METHOD="EMAIL"
    fi
  
    # Deploy the certificate using CloudFormation
    aws cloudformation deploy \
      --template-file cfn/tls-certificate.yaml \
      --stack-name $TLS_CERTIFICATE_STACK \
      --parameter-overrides \
        DomainName=$DOMAIN_NAME \
        CertificateType=$CERT_TYPE \
        ValidationMethod=$VALIDATION_METHOD \
        HostedZoneId=$HOSTED_ZONE_ID \
        CustomSubdomains=${CUSTOM_SUBDOMAINS:-''} \
      --no-fail-on-empty-changeset
      
    # Get the certificate ARN from the stack outputs
    ACM_CERTIFICATE_ARN=$(aws cloudformation describe-stacks \
          --stack-name $TLS_CERTIFICATE_STACK \
          --query "Stacks[0].Outputs[?OutputKey=='CertificateArn'].OutputValue" \
          --output text)
        
    echo "Certificate ARN: $ACM_CERTIFICATE_ARN"
fi
