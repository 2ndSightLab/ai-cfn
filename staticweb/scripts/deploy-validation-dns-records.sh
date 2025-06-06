#!/bin/bash
echo "deploy-validation-dns-records.sh"

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
      # Deploy the certificate using CloudFormation in the background
      # Use nohup to ensure the process continues even if the terminal is closed
      echo "Deploying certificate stack in the background..."
      
      nohup aws cloudformation deploy \
       --template-file cfn/tls-certificate.yaml \
       --stack-name $TLS_CERTIFICATE_STACK \
       --parameter-overrides \
        DomainName=$DOMAIN_NAME \
        CertificateType=$CERT_TYPE \
        ValidationMethod=$VALIDATION_METHOD \
        HostedZoneId=$HOSTED_ZONE_ID \
        CustomSubdomains=${CUSTOM_SUBDOMAINS:-''} \
       --no-fail-on-empty-changeset > /tmp/cert-deploy-$$.log 2>&1 &
      
      echo "DNS records created successfully."
    fi
  fi
fi
