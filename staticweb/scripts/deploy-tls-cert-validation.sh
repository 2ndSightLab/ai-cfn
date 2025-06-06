echo "deploy-tls-cert-validation.sh"

REGION="$1"
CERT_VALIDATION_STACK="$2"
TLS_CERTIFICATION_STACK="$3"

# Loop until we find validation records in stack events
echo "Waiting for validation records to appear in stack events..."
MAX_ATTEMPTS=30
ATTEMPT=0
FOUND_RECORDS=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
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

echo "$VALIDATION_RECORDS" | while read -r RECORD; do
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

