#!/bin/bash
function delete_existing_certificates(){
  DOMAIN_NAME="$1"
  
  echo "scripts/functions/delete-existing-certificates.sh"

  stack_name=$TLS_CERTIFICATE_STACK

  if aws cloudformation describe-stacks --stack-name $stack_name --region $region &>/dev/null; then
  
    echo "Delete certificate stack with retain-resources"  
    aws cloudformation delete-stack --stack-name $stack_name --region $region --retain-resources
        
    echo "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $region
    echo "Stack deletion complete."
  
  fi 
  
  echo "Searching for certificates to delete..."  
  # List all certificates for the domain
  # Note: We're not using --include-expired as it's not supported
  CERT_ARNS=$(aws acm list-certificates \
    --region us-east-1 \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" \
    --output text)
  
  if [[ -z "$CERT_ARNS" ]]; then
    echo "No certificates found for $DOMAIN_NAME"
  else
    echo "Found certificates: $CERT_ARNS"
    
    # Try to delete each certificate
    for CERT_ARN in $CERT_ARNS; do
      echo "Attempting to delete certificate: $CERT_ARN"
      if aws acm delete-certificate --certificate-arn $CERT_ARN --region us-east-1; then
        echo "Successfully deleted certificate: $CERT_ARN"
      else
        echo "Failed to delete certificate: $CERT_ARN"
        echo "This certificate might be in use by another AWS service."
        echo "Please check the AWS Console and manually remove any resources using this certificate."
      fi
    done
  fi
  
}
