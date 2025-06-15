#!/bin/bash
echo "scripts/deploy/acm-tls-cert.sh"

# Override Region 
CERT_REGION=us-east-1

# TLS Certificate 
ACM_CERTIFICATE_ARN=""

read -p "Deploy TLS certificate? (y/n): " DEPLOY_TLS_CERTIFICATE
if [[ "$DEPLOY_TLS_CERTIFICATE" == "y" || "$DEPLOY_TLS_CERTIFICATE" == "Y" ]]; then

   echo "Any existing certificates for $DOMAIN_NAME will cause this process to fail."
   read -p "Delete existing TLS certificates for $DOMAIN_NAME? (y/n): " DELETE_TLS_CERTIFICATE
   if [[ "$DELETE_TLS_CERTIFICATE" == "y" || "$DELETE_TLS_CERTIFICATE" == "Y" ]]; then
      delete_existing_certificates $DOMAIN_NAME $TLS_CERTIFICATE_STACK $CERT_REGION
   fi
   
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
    delete_failed_stack_if_exists $TLS_CERTIFICATE_STACK $CERT_REGION

   # Starting validation script to wait for certificate stack
   ./scripts/deploy/route53-tls-cert-validation.sh $CERT_VALIDATION_STACK $TLS_CERTIFICATE_STACK $HOSTED_ZONE_ID $DOMAIN_NAME $DOMAIN_TYPE $CERT_REGION $ACM_CERTIFICATE_ARN &

    # Deploy certificate
    aws cloudformation deploy \
        --template-file cfn/acm-tls-certificate.yaml \
        --stack-name $TLS_CERTIFICATE_STACK \
        --parameter-overrides \
          DomainName=$DOMAIN_NAME \
          CertificateType=$DOMAIN_TYPE \
          ValidationMethod=$VALIDATION_METHOD \
          HostedZoneId=$HOSTED_ZONE_ID \
          CustomSubdomains=${CUSTOM_SUBDOMAINS:-''} \
        --no-fail-on-empty-changeset
        --region $CERT_REGION
        
    stack_exists $TLS_CERTIFICATE_STACK $CERT_REGION
      
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
        --region $CERT_REGION
        --query "StackResourceSummaries[?ResourceType=='AWS::CertificateManager::Certificate'].PhysicalResourceId" \
        --output text)
      
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
    #must wait for the child process to complete before exiting or bad things happen
    echo "Wait"
    wait
    
else
    echo "Get certificate ARN"
    ACM_CERTIFICATE_ARN=$(aws cloudformation list-stack-resources \
      --stack-name $TLS_CERTIFICATE_STACK \
      --region $CERT_REGION
      --query "StackResourceSummaries[?ResourceType=='AWS::CertificateManager::Certificate'].PhysicalResourceId" \
      --output text 2)
fi

echo "ACM_CERTIFICATE_ARN: $ACM_CERTIFICATE_ARN"



