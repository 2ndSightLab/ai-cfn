#!/bin/bash

echo "scripts/deploy/route53-tls-cert-validation.sh"

source ./scripts/functions/delete-failed-stack-if-exists.sh
source ./scripts/functions/stack-exists.sh
source ./scripts/functions/delete-stack.sh

# Arguments
CERT_VALIDATION_STACK_PREFIX="$1"
TLS_CERTIFICATE_STACK="$2"
HOSTED_ZONE_ID="$3"
DOMAIN_NAME="$4"
DOMAIN_TYPE="$5"
REGION="$6"

echo "scripts/deploy/route53-validation-dns-records.sh"
echo "CERT_VALIDATION_STACK_PREFIX=$CERT_VALIDATION_STACK_PREFIX"
echo "TLS_CERTIFICATE_STACK=$TLS_CERTIFICATE_STACK"
echo "HOSTED_ZONE_ID=$HOSTED_ZONE_ID"
echo "DOMAIN_NAME=$DOMAIN_NAME"
echo "DOMAIN_TYPE=$DOMAIN_TYPE"
echo "REGION=$REGION"

delete_stack $CERT_VALIDATION_STACK_PREFIX $REGION
delete_stack $CERT_VALIDATION_STACK_PREFIX-WWW $REGION
delete_stack $CERT_VALIDATION_STACK_PREFIX-Wildcard $REGION
delete_stack $CERT_VALIDATION_STACK_PREFIX-Subdomain $REGION

# Initialize loop variables
MAX_ATTEMPTS=10
ATTEMPT=0
RECORD_COUNT=0

echo "Waiting for stack $TLS_CERTIFICATE_STACK to become available"
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

echo "Checking for validation records"
VALIDATION_ATTEMPTS=0
MAX_VALIDATION_ATTEMPTS=10

while [ $VALIDATION_ATTEMPTS -lt $MAX_VALIDATION_ATTEMPTS ]; do
  # Get stack events and check for validation records
  STACK_EVENTS=$(aws cloudformation describe-stack-events --stack-name "$TLS_CERTIFICATE_STACK" --region $REGION)
  VALIDATION_INFO=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:" || echo "")
  
  if [ -n "$VALIDATION_INFO" ]; then
    echo "Found validation records!"
    # Extract validation records using grep instead of jq for the pattern matching
    RECORD=$(echo "$STACK_EVENTS" | jq -r '.StackEvents[].ResourceStatusReason' | grep -F "Content of DNS Record is:")
    
    echo "VALIDATION_RECORDS: $RECORD"
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

echo "Validation records exist. Parsing validation records from $RECORD"
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
    CURRENT_VALIDATION_STACK="${CERT_VALIDATION_STACK_PREFIX}"

    # Delete the stack if it exists and is in a failed state
    delete_failed_stack_if_exists $CURRENT_VALIDATION_STACK $REGION
    
    # Create parameters for this validation record
    PARAMS="HostedZoneId=$HOSTED_ZONE_ID DomainName=$DOMAIN_NAME RecordName=\"$RECORD_NAME\" RecordValue=\"$RECORD_VALUE\""
    
    # Deploy the validation stack for this record
    echo "Deploying validation stack: $CURRENT_VALIDATION_STACK"
    echo "Parameters: $PARAMS"

    echo "Creating validation stack..."
    eval "aws cloudformation deploy \
      --template-file cfn/route53-tls-certificate-validation.yaml \
      --stack-name $CURRENT_VALIDATION_STACK \
      --parameter-overrides $PARAMS \
      --region $REGION \
      --no-fail-on-empty-changeset"
    
    # Check if the stack was created successfully
    stack_exists $CURRENT_VALIDATION_STACK $REGION
    
    echo "TLS Certificate Validation DNS record created successfully for $DOMAIN_NAME"
else
    echo "Validation record details not found in CloudFormation stack: $TLS_CERTIFICATE_STACK" 
fi

echo "Checking for subdomain records"
SUBDOMAIN=""
if [ "$DOMAIN_TYPE" == "WWW" ]; then SUBDOMAIN="www.$DOMAIN_NAME"; fi
if [ "$DOMAIN_TYPE" == "*" ]; then SUBDOMAIN="*.$DOMAIN_NAME"; fi

echo "SUBDOMAIN: $SUBDOMAIN"

if [ "$SUBDOMAIN" != "" ]; then

  ACM_CERTIFICATE_ARN=$(aws cloudformation list-stack-resources \
        --stack-name $TLS_CERTIFICATE_STACK \
        --query "StackResourceSummaries[?ResourceType=='AWS::CertificateManager::Certificate'].PhysicalResourceId" \
        --output text 2>/dev/null)
        
  echo "Adding validation record for subdomain: $SUBDOMAIN"

  CURRENT_VALIDATION_STACK="${CERT_VALIDATION_STACK_PREFIX}-${DOMAIN_TYPE}"
  delete_stack $CURRENT_VALIDATION_STACK $REGION

  echo "Searching cert for validation record: $ACM_CERTIFICATE_ARN"

  VALIDATION_RECORD=$(aws acm describe-certificate --region $REGION --certificate-arn "$ACM_CERTIFICATE_ARN" | \
       jq -r --arg SUBDOMAIN "$SUBDOMAIN" '.Certificate.DomainValidationOptions[] | select(.DomainName == $SUBDOMAIN)')

  if [ -z "$VALIDATION_RECORD" ] || [ "$VALIDATION_RECORD" == "null" ]; then
    echo "No validation record found for $SUBDOMAIN"
    exit 1
  fi

  RECORD_NAME=$(echo "$VALIDATION_RECORD" | jq -r '.ResourceRecord.Name')
  RECORD_TYPE=$(echo "$VALIDATION_RECORD" | jq -r '.ResourceRecord.Type')
  RECORD_VALUE=$(echo "$VALIDATION_RECORD" | jq -r '.ResourceRecord.Value')

  echo "Found validation record for $SUBDOMAIN:"
  echo "Record Name: $RECORD_NAME"
  echo "Record Type: $RECORD_TYPE"
  echo "Record Value: $RECORD_VALUE"
    
  # Delete the stack if it exists and is in a failed state
  delete_failed_stack_if_exists $CURRENT_VALIDATION_STACK $REGION
    
  # Create parameters for this validation record
  PARAMS="HostedZoneId=$HOSTED_ZONE_ID DomainName=$SUBDOMAIN RecordName=\"$RECORD_NAME\" RecordValue=\"$RECORD_VALUE\""
    
  # Deploy the validation stack for this record
  echo "Deploying validation stack: $CURRENT_VALIDATION_STACK"
  echo "Parameters: $PARAMS"

  echo "Creating validation stack..."
  eval "aws cloudformation deploy \
      --template-file cfn/route53-tls-certificate-validation.yaml \
      --stack-name $CURRENT_VALIDATION_STACK \
      --parameter-overrides $PARAMS \
      --region $REGION \
      --no-fail-on-empty-changeset"
    
  # Check if the stack was created successfully
  stack_exists $CURRENT_VALIDATION_STACK $REGION
    
  echo "TLS Certificate Validation DNS record created successfully for $SUBDOMAIN."
     
fi
echo "Finished adding TLS Certificate validation records."




