#!/bin/bash -e

echo "deploy-tls-cert-validation.sh"

REGION="$1"
CERT_VALIDATION_STACK="$2"
TLS_CERTIFICATE_STACK="$3"
DOMAIN_NAME="$4"

# Look for validation records immediately
echo "Looking for validation records in stack events..."
MAX_ATTEMPTS=30
ATTEMPT=0
FOUND_RECORDS=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  # Check if stack exists first
  aws cloudformation describe-stacks --stack-name $TLS_CERTIFICATE_STACK --region $REGION > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Certificate stack does not exist yet. Waiting..."
    ATTEMPT=$((ATTEMPT+1))
    sleep 10
    continue
  fi
  
  # Get stack events
  STACK_EVENTS=$(aws cloudformation describe-stack-events \
    --stack-name $TLS_CERTIFICATE_STACK \
    --output json)
  
  # Check if any event contains validation information
  VALIDATION_INFO=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:" || echo "")
  
  if [ -n "$VALIDATION_INFO" ]; then
    echo "Found validation records!"
    FOUND_RECORDS=true
    break
  fi
  
  # Increment attempt counter and wait
  ATTEMPT=$((ATTEMPT+1))
  echo "Waiting for validation records to appear (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
  sleep 10
done

# Check if we exceeded max attempts
if [ "$FOUND_RECORDS" = false ]; then
  echo "Timed out waiting for validation records to appear. Please check the AWS console."
  exit 1
fi

# Extract validation records using grep instead of jq for the pattern matching
VALIDATION_RECORDS=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:")

# Parse validation records
# Format is typically: "Content of DNS Record is: {Name: _x1.example.com,Type: CNAME,Value: _x2.acm-validations.aws.}"
PARAMS="HostedZoneId=$HOSTED_ZONE_ID DomainName=$DOMAIN_NAME"
RECORD_COUNT=0

# Store validation records in an array to avoid subshell issues
mapfile -t VALIDATION_RECORD_ARRAY <<< "$VALIDATION_RECORDS"

for RECORD in "${VALIDATION_RECORD_ARRAY[@]}"; do
  # Extract record name, type, and value using regex
  if [[ $RECORD =~ Name:\ ([^,]+),Type:\ ([^,]+),Value:\ ([^}]+) ]]; then
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

if [ $RECORD_COUNT -eq 0 ]; then
  echo "Error: Failed to parse any validation records."
  exit 1
fi

# Deploy the validation stack
echo "Deploying validation stack: $CERT_VALIDATION_STACK"
echo "Parameters: $PARAMS"

# Check if validation stack exists and delete if it does
aws cloudformation describe-stacks --stack-name $CERT_VALIDATION_STACK --region $REGION > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Validation stack already exists. Deleting..."
  aws cloudformation delete-stack --stack-name $CERT_VALIDATION_STACK --region $REGION
  echo "Waiting for stack deletion to complete..."
  aws cloudformation wait stack-delete-complete --stack-name $CERT_VALIDATION_STACK --region $REGION
fi

# Deploy the validation stack
echo "Creating validation stack..."
eval "aws cloudformation deploy \
  --template-file cfn/tls-certificate-validation.yaml \
  --stack-name $CERT_VALIDATION_STACK \
  --parameter-overrides $PARAMS \
  --region $REGION \
  --no-fail-on-empty-changeset"

echo "Validation stack deployment complete!"
echo "Certificate validation records have been created in Route 53."
echo "It may take some time for AWS to validate the certificate."


