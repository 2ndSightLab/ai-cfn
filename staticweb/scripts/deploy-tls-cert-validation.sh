#!/bin/bash

source ./scripts/delete_failed_stack_if_exists.sh
source ./scripts/stack_exists.sh

# Arguments
CERT_VALIDATION_STACK_PREFIX="$1"
TLS_CERTIFICATE_STACK="$2"
HOSTED_ZONE_ID="$3"
DOMAIN_NAME="$4"
REGION="$5"

echo "deploy-validation-dns-records.sh"

# Initialize loop variables
MAX_ATTEMPTS=5
ATTEMPT=0
RECORD_COUNT=0

# Check if the TLS_CERTIFICATE_STACK exists, with up to 5 attempts
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if aws cloudformation describe-stacks --stack-name "$TLS_CERTIFICATE_STACK" --region $REGION >/dev/null 2>&1; then
    echo "TLS Certificate stack '$TLS_CERTIFICATE_STACK' exists. Checking for validation records..."
    break
  else
    echo "Attempt $((ATTEMPT+1)): TLS Certificate stack '$TLS_CERTIFICATE_STACK' does not exist yet. Waiting..."
    ATTEMPT=$((ATTEMPT+1))
    
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
      sleep 10
    else
      echo "Error: Maximum attempts reached. TLS Certificate stack '$TLS_CERTIFICATE_STACK' not found."
      exit 1
    fi
  fi
done

# Now check for validation records in a separate loop
VALIDATION_ATTEMPTS=0
MAX_VALIDATION_ATTEMPTS=5

while [ $VALIDATION_ATTEMPTS -lt $MAX_VALIDATION_ATTEMPTS ]; do
  # Get stack events and check for validation records
  STACK_EVENTS=$(aws cloudformation describe-stack-events --stack-name "$TLS_CERTIFICATE_STACK" --region $REGION)
  VALIDATION_INFO=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:" || echo "")
  
  if [ -n "$VALIDATION_INFO" ]; then
    echo "Found validation records!"
    # Extract validation records using grep instead of jq for the pattern matching
    VALIDATION_RECORDS=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:")
    
    echo "VALIDATION_RECORDS: $VALIDATION_RECORDS"
    
    break
  else
    echo "Attempt $((VALIDATION_ATTEMPTS+1)): No validation records found yet. Waiting..."
    VALIDATION_ATTEMPTS=$((VALIDATION_ATTEMPTS+1))
    
    if [ $VALIDATION_ATTEMPTS -lt $MAX_VALIDATION_ATTEMPTS ]; then
      sleep 10
    else
      echo "Error: Maximum attempts reached. No validation records found in stack '$TLS_CERTIFICATE_STACK'."
      exit 1
    fi
  fi
done

# Store validation records in an array to avoid subshell issues
mapfile -t VALIDATION_RECORD_ARRAY <<< "$VALIDATION_RECORDS"

# Loop through each validation record and create a separate stack for each
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
    
    # Create a unique stack name for this validation record
    CURRENT_VALIDATION_STACK="${CERT_VALIDATION_STACK_PREFIX}-${RECORD_COUNT}"
    
    # Delete the stack if it exists and is in a failed state
    delete-failed-stack-if-exists $CURRENT_VALIDATION_STACK $REGION
    
    # Create parameters for this validation record
    PARAMS="HostedZoneId=$HOSTED_ZONE_ID DomainName=$DOMAIN_NAME RecordName=\"$RECORD_NAME\" RecordValue=\"$RECORD_VALUE\""
    
    # Deploy the validation stack for this record
    echo "Deploying validation stack: $CURRENT_VALIDATION_STACK"
    echo "Parameters: $PARAMS"

    echo "Creating validation stack..."
    eval "aws cloudformation deploy \
      --template-file cfn/tls-certificate-validation.yaml \
      --stack-name $CURRENT_VALIDATION_STACK \
      --parameter-overrides $PARAMS \
      --region $REGION \
      --no-fail-on-empty-changeset"
    
    # Check if the stack was created successfully
    stack_exists $CURRENT_VALIDATION_STACK $REGION
    
    echo "TLS Certificate Validation DNS record $RECORD_COUNT created successfully."
  fi
done

if [ $RECORD_COUNT -eq 0 ]; then
  echo "Error: Failed to parse any validation records." && exit 1
else
  echo "Total TLS Certificate Validation DNS records created: $RECORD_COUNT"
fi






