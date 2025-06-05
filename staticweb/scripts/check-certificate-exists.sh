#!/bin/bash

# Function to check if a certificate exists and is valid
check_certificate_exists() {
  local domain=$1
  local region=${2:-us-east-1}
  
  echo "Thoroughly checking for existing certificates for $domain..."
  
  # List only ISSUED or PENDING_VALIDATION certificates
  local valid_certs=$(aws acm list-certificates \
    --region $region \
    --certificate-statuses "ISSUED" "PENDING_VALIDATION" \
    --query "CertificateSummaryList[?DomainName=='$domain'].CertificateArn" \
    --output text)
  
  if [[ -z "$valid_certs" ]]; then
    echo "No valid certificates found for $domain"
    return 1
  fi
  
  echo "Found potentially valid certificate ARNs: $valid_certs"
  
  # Check each certificate
  for cert_arn in $valid_certs; do
    echo "Checking certificate: $cert_arn"
    
    local describe_result
    if ! describe_result=$(aws acm describe-certificate --certificate-arn "$cert_arn" --region $region); then
      echo "Certificate $cert_arn cannot be described - might be in an inconsistent state"
      continue
    fi
    
    local status=$(echo "$describe_result" | jq -r '.Certificate.Status')
    
    echo "Certificate status: $status"
    
    # Only consider ISSUED or PENDING_VALIDATION certificates as valid
    if [[ "$status" == "ISSUED" || "$status" == "PENDING_VALIDATION" ]]; then
      echo "Found valid certificate: $cert_arn with status: $status"
      ACM_CERTIFICATE_ARN=$cert_arn
      return 0
    fi
  done
  
  echo "No valid certificates found for $domain"
  return 1
}
