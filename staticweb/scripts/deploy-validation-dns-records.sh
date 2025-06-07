#!/bin/bash
echo "deploy-validation-dns-records.sh"

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

echo "DNS records created successfully."
      
