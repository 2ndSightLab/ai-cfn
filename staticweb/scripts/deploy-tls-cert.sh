#!/bin/bash
echo "deploy-tls-cert.sh"

# Override Region 
REGION=us-east-1

# TLS Certificate 
ACM_CERTIFICATE_ARN=""

# Check if any valid certificates exist
if check_certificate_exists "$DOMAIN_NAME" "us-east-1"; then
  echo "Existing certificate ARN: $ACM_CERTIFICATE_ARN"
else
  echo "No valid certificates found for $DOMAIN_NAME"
  ACM_CERTIFICATE_ARN=""
fi

#causes problems due to child process
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
    
    # Check if stack exists and delete if failed
    delete_failed_stack_if_exists $TLS_CERTIFICATE_STACK $REGION

   # Starting validation script to wait for certificate stack
   ./scripts/deploy-tls-cert-validation.sh $CERT_VALIDATION_STACK $TLS_CERTIFICATE_STACK $HOSTED_ZONE_ID $DOMAIN_NAME $REGION &

    # Deploy certificate
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
        
    stack_exists $TLS_CERTIFICATE_STACK $REGION
      
    echo "Certificate stack creation has been initiated."
    echo "Stack name: $TLS_CERTIFICATE_STACK"
    echo "Waiting for certificate ARN to become available..."

      # Loop until the ARN is available
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
      # Try to get the certificate ARN from stack resources
      # Look for a resource of type AWS::CertificateManager::Certificate
      ACM_CERTIFICATE_ARN=$(aws cloudformation list-stack-resources \
        --stack-name $TLS_CERTIFICATE_STACK \
        --query "StackResourceSummaries[?ResourceType=='AWS::CertificateManager::Certificate'].PhysicalResourceId" \
        --output text 2>/dev/null)
      
      # Check if we got a valid ARN
      if [ -n "$ACM_CERTIFICATE_ARN" ] && [ "$ACM_CERTIFICATE_ARN" != "None" ]; then
        echo "Certificate ARN: $ACM_CERTIFICATE_ARN"
        break
      fi
      
      # Increment attempt counter and wait
      ATTEMPT=$((ATTEMPT+1))
      echo "Waiting for certificate ARN to become available (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
      sleep 5
    done
    
    # Check if we exceeded max attempts
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
      echo "Timed out waiting for certificate ARN. You can check the CloudFormation console for status."
      echo "Stack name: $TLS_CERTIFICATE_STACK"
    fi
fi

echo "ACM_CERTIFICATE_ARN: $ACM_CERTIFICATE_ARN"
    

# Wait for the validation stack to be created
  echo "Waiting for validation stack to be created..."
  MAX_ATTEMPTS=30
  ATTEMPT=0
  VALIDATION_STACK_CREATED=false
  
  while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Check if validation stack exists
    aws cloudformation describe-stacks --stack-name $CERT_VALIDATION_STACK --region $REGION > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "Validation stack has been created."
      VALIDATION_STACK_CREATED=true
      break
    fi
    
    ATTEMPT=$((ATTEMPT+1))
    echo "Waiting for validation stack to be created (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    sleep 10
  done
  
  if [ "$VALIDATION_STACK_CREATED" = false ]; then
    echo "WARNING: Validation stack was not created within the timeout period."
    echo "The certificate may not be validated automatically."
  else
    echo "Validation stack created successfully: $CERT_VALIDATION_STACK"
  fi


