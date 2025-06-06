#!/bin/bash
echo "deploy-tls-cert-validation.sh"

REGION="$1"
CERT_VALIDATION_STACK="$2"
TLS_CERTIFICATE_STACK="$3"

echo "Certificate ARN: $ACM_CERTIFICATE_ARN"
# Loop until the stack exists and we can get its parameters
echo "Waiting for stack to be created..."
MAX_ATTEMPTS=30
ATTEMPT=0
STACK_PARAMS=""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  # Try to get stack parameters
  STACK_PARAMS=$(aws cloudformation describe-stacks \
    --stack-name $TLS_CERTIFICATE_STACK \
    --query 'Stacks[0].Parameters' \
    --output json 2>/dev/null)
  
  # Check if we got valid parameters
  if [ $? -eq 0 ] && [ -n "$STACK_PARAMS" ] && [ "$STACK_PARAMS" != "null" ]; then
    echo "Stack exists! Retrieved stack parameters."
    break
  fi
  
  # Increment attempt counter and wait
  ATTEMPT=$((ATTEMPT+1))
  echo "Waiting for stack to be created (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
  sleep 5
done

# Check if we exceeded max attempts
if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
  echo "Timed out waiting for stack to be created. Please check the AWS console."
  exit 1
fi
  
  CERT_TYPE=$(echo "$STACK_PARAMS" | jq -r '.[] | select(.ParameterKey=="CertificateType").ParameterValue')
  DOMAIN_NAME=$(echo "$STACK_PARAMS" | jq -r '.[] | select(.ParameterKey=="DomainName").ParameterValue')
  
  echo "Certificate type: $CERT_TYPE"
  echo "Domain name: $DOMAIN_NAME"
  
  # Get stack events to find validation records
  STACK_EVENTS=$(aws cloudformation describe-stack-events \
    --stack-name $TLS_CERTIFICATE_STACK \
    --output json)
  
  # Extract validation records from stack events
  # Look for ResourceStatusReason containing "Content of DNS Record is:"
  VALIDATION_EVENTS=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[] | select(.ResourceType=="AWS::CertificateManager::Certificate" and .ResourceStatusReason!=null and contains(.ResourceStatusReason, "Content of DNS Record is:")) | .ResourceStatusReason')
  
  if [[ -z "$VALIDATION_EVENTS" ]]; then
    echo "Error: Could not find validation records in stack events."
    exit 1
  fi
  
  # Parse validation records
  # Format is typically: "Content of DNS Record is: {Name: _x1.example.com,Type: CNAME,Value: _x2.acm-validations.aws.}"
  echo "Found validation records:"
  
  # Create parameter overrides for CloudFormation
  PARAMS="HostedZoneId=$HOSTED_ZONE_ID DomainName=$DOMAIN_NAME"
  
  # Counter for validation records
  RECORD_COUNT=0
  
  # Process each validation event
  echo "$VALIDATION_EVENTS" | while IFS= read -r EVENT; do
    # Extract record name, type, and value using regex
    if [[ $EVENT =~ Name:\ ([^,]+),Type:\ ([^,]+),Value:\ ([^}]+) ]]; then
      RECORD_NAME="${BASH_REMATCH[1]}"
      RECORD_TYPE="${BASH_REMATCH[2]}"
      RECORD_VALUE="${BASH_REMATCH[3]}"
      
      RECORD_COUNT=$((RECORD_COUNT+1))
      
      echo "Record $RECORD_COUNT:"
      echo "  Name: $RECORD_NAME"
      echo "  Type: $RECORD_TYPE"
      echo "  Value: $RECORD_VALUE"
      
      # Add to parameters
      PARAMS="$PARAMS ValidationDomain${RECORD_COUNT}RecordName=\"$RECORD_NAME\" ValidationDomain${RECORD_COUNT}RecordValue=\"$RECORD_VALUE\" ValidationDomain${RECORD_COUNT}RecordType=\"$RECORD_TYPE\""
    fi
  done
  
  # Add record count to parameters
  PARAMS="$PARAMS ValidationRecordCount=$RECORD_COUNT"
  
  echo "Deploying certificate validation DNS records..."
  echo "Parameters: $PARAMS"
  
  # Deploy the CloudFormation stack with the validation records
  eval aws cloudformation deploy \
    --template-file cfn/certificate-validation.yaml \
    --stack-name $CERT_VALIDATION_STACK \
    --parameter-overrides $PARAMS \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
  
  echo "Certificate validation records created. Validation in progress..."
  
  # Check if the user wants to wait for validation
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
