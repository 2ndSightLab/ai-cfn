#!/bin/bash

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
  
  # Check if validation records already exist
  if [[ "$VALIDATION_NEEDED" == "true" ]]; then
    if stack_exists $CERT_VALIDATION_STACK; then
      echo "Certificate validation stack already exists."
      echo "Checking if validation records match the current certificate..."
      
      # Get current validation record details
      VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
        --certificate-arn $ACM_CERTIFICATE_ARN \
        --region us-east-1 \
        --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN_NAME'].ResourceRecord.Name" \
        --output text)
      
      # Get existing validation record from CloudFormation stack
      EXISTING_VALIDATION_RECORD=$(aws cloudformation describe-stacks \
        --stack-name $CERT_VALIDATION_STACK \
        --query "Stacks[0].Parameters[?ParameterKey=='ValidationDomain1RecordName'].ParameterValue" \
        --output text)
      
      if [[ "$VALIDATION_RECORD_NAME" == "$EXISTING_VALIDATION_RECORD" ]]; then
        echo "Existing validation records match the current certificate."
        echo "No need to update validation records."
        UPDATE_VALIDATION=false
      else
        echo "Validation records do not match the current certificate."
        read -p "Update validation records? (y/n): " UPDATE_VALIDATION_INPUT
        if [[ "$UPDATE_VALIDATION_INPUT" == "y" || "$UPDATE_VALIDATION_INPUT" == "Y" ]]; then
          UPDATE_VALIDATION=true
        else
          UPDATE_VALIDATION=false
        fi
      fi
    else
      echo "No validation stack found. Need to create validation records."
      UPDATE_VALIDATION=true
    fi
    
    if [[ "$UPDATE_VALIDATION" == "true" ]]; then
      # Get validation record details for the main domain
      VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
        --certificate-arn $ACM_CERTIFICATE_ARN \
        --region us-east-1 \
        --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN_NAME'].ResourceRecord.Name" \
        --output text)
      
      VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
        --certificate-arn $ACM_CERTIFICATE_ARN \
        --region us-east-1 \
        --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN_NAME'].ResourceRecord.Value" \
        --output text)
      
      # Get validation record details for the www subdomain if included
      if [[ "$INCLUDE_WWW" == "true" ]]; then
        WWW_VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
          --certificate-arn $ACM_CERTIFICATE_ARN \
          --region us-east-1 \
          --query "Certificate.DomainValidationOptions[?DomainName=='www.$DOMAIN_NAME'].ResourceRecord.Name" \
          --output text)
        
        WWW_VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
          --certificate-arn $ACM_CERTIFICATE_ARN \
          --region us-east-1 \
          --query "Certificate.DomainValidationOptions[?DomainName=='www.$DOMAIN_NAME'].ResourceRecord.Value" \
          --output text)
      else
        WWW_VALIDATION_RECORD_NAME=""
        WWW_VALIDATION_RECORD_VALUE=""
      fi
      
      echo "Deploying certificate validation DNS records..."
      aws cloudformation deploy \
        --template-file cfn/certificate-validation.yaml \
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
    fi
  fi
  
  # Check if the user wants to wait for validation
  if [[ "$VALIDATION_NEEDED" == "true" ]]; then
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
          echo "Certificate validation complete!"
          break
        elif [[ "$CERT_STATUS" == "FAILED" ]]; then
          echo "Certificate validation failed. Please check the AWS console for details."
          break
        fi
        
        sleep 30
      done
    fi
  fi
fi
