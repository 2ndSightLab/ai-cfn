#/bin/bash
echo "delete-existing-certificates.sh"

# Ask if user wants to force delete any existing certificates
read -p "Force delete any existing certificates for $DOMAIN_NAME? (y/n): " FORCE_DELETE_CERT
if [[ "$FORCE_DELETE_CERT" == "y" || "$FORCE_DELETE_CERT" == "Y" ]]; then
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
fi
