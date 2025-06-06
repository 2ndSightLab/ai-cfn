#!/bin/bash

# Check if validation is already complete
CERT_STATUS=$(aws acm describe-certificate \
      --certificate-arn $ACM_CERTIFICATE_ARN \
      --region us-east-1 \
      --query 'Certificate.Status' \
      --output text)
    
if [[ "$CERT_STATUS" == "ISSUED" ]]; then
    echo "Certificate is already validated and active."

else
    
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
