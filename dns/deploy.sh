#!/bin/bash

# Function to deploy CloudFormation stack
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters=$3

    echo "Deploying stack: $stack_name"
    echo "Using template: $template_file"
    echo "With parameters: $parameters"
    
    aws cloudformation deploy \
      --stack-name "$stack_name" \
      --template-file "$template_file" \
      --parameter-overrides $parameters
    
    echo "Deployment initiated. You can check the status of your stack with:"
    echo "aws cloudformation describe-stacks --stack-name \"$stack_name\""
}

# Prompt for the domain name
read -p "Enter your domain name: " DOMAIN_NAME

# Ensure domain name has a trailing dot
if [[ "$DOMAIN_NAME" != *. ]]; then
    DOMAIN_NAME="${DOMAIN_NAME}."
fi

# Create stack name base by replacing dots with hyphens (excluding the trailing dot)
STACK_NAME_BASE=$(echo ${DOMAIN_NAME%?} | tr '.' '-')

# Ask which type of DNS record to deploy
echo "Which type of DNS record or configuration do you want to deploy?"
echo "1) Google DKIM"
echo "2) Google MAIL"
echo "3) Google SPF"
echo "4) TXT"
echo "5) CNAME"
echo "6) CAA"
echo "7) DNSSEC"
read -p "Enter your choice (1-7): " RECORD_CHOICE

# Use case statement to handle different record types
case $RECORD_CHOICE in
  1)
    RECORD_TYPE="google-dkim"
    echo "Log in to your Google Workspace Admin Console"
    echo
    echo "Go to admin.google.com and sign in with your administrator account"
    echo "Navigate to DKIM settings"
    echo
    echo "Click on \"Apps\" in the left sidebar"
    echo "Click on \"Google Workspace\" > \"Gmail\" > \"Authenticate email\""
    echo "Select the \"DKIM\" tab"
    echo "Generate the DKIM key"
    echo
    echo "Select your domain from the list"
    echo "Click on \"Generate new record\" if you haven't already generated a DKIM key"
    echo "If you already have a key, you'll see the DKIM information displayed"
    read -p "Enter the full DKIM value (v=DKIM1; k=rsa; p=...): " DKIM_VALUE
    PARAMS="DomainName=$DOMAIN_NAME DKIMValue=$DKIM_VALUE"
    ;;
  2)
    RECORD_TYPE="google-mail"
    PARAMS="DomainName=$DOMAIN_NAME"
    ;;
  3)
    RECORD_TYPE="google-spf"
    PARAMS="DomainName=$DOMAIN_NAME"
    ;;
  4)
    RECORD_TYPE="txt"
    read -p "Enter TXT record name (without domain): " TXT_NAME
    read -p "Enter TXT record value: " TXT_VALUE
    PARAMS="DomainName=$DOMAIN_NAME RecordName=$TXT_NAME RecordValue=$TXT_VALUE"
    ;;
  5)
    RECORD_TYPE="cname"
    read -p "Enter CNAME record name (without domain): " CNAME_NAME
    read -p "Enter CNAME target: " CNAME_TARGET
    PARAMS="DomainName=$DOMAIN_NAME RecordName=$CNAME_NAME RecordValue=$CNAME_TARGET"
    ;;
  6)
    RECORD_TYPE="caa"
    echo "In CAA records, the flags field can have values from 0 to 255, but in practice, only two values are commonly used:"
    echo
    echo "0: This is the default value and indicates standard handling. If a Certificate Authority doesn't understand a particular tag in your CAA record, it can safely ignore that tag and proceed with certificate issuance."
    echo
    echo "128: This is the \"critical\" flag. It tells Certificate Authorities that if they don't understand any tag in this CAA record, they MUST NOT issue a certificate. This is a stricter setting that ensures only CAs that fully understand your CAA record will issue certificates."
    echo
    echo "For most standard use cases, you would enter \"0\" at this prompt. You would only use \"128\" if you have specific security requirements that demand stricter handling of your CAA records."
    read -p "Enter CAA record flags (0-255): " CAA_FLAGS
    echo
    echo "issue: This tag authorizes a specific Certificate Authority (CA) to issue standard SSL/TLS certificates for your domain. For example, if you set this to \"letsencrypt.org\", only Let's Encrypt would be allowed to issue certificates for your domain."
    echo
    echo "issuewild: This tag specifically controls which CAs can issue wildcard certificates (certificates that cover *.yourdomain.com) for your domain. You might want different policies for wildcard certificates versus regular certificates."
    echo
    echo "iodef: This tag specifies a URL or email address where CAs should report policy violations or certificate issuance requests that don't comply with your domain's CAA records. It's essentially a reporting mechanism for security incidents."
    read -p "Enter CAA record tag (issue/issuewild/iodef): " CAA_TAG
    
    if [[ "$CAA_TAG" == "issue" || "$CAA_TAG" == "issuewild" ]]; then
        echo "Enter the domain name of the Certificate Authority (CA) you want to authorize."
        echo "For AWS Certificate Manager, you can use: amazon.com, amazontrust.com, awstrust.com, or amazonaws.com"
        echo "Any of the above values will work for AWS"
        echo "Other examples: letsencrypt.org, digicert.com, sectigo.com"
        echo "To allow any CA, enter \";\""
        read -p "Enter CA domain: " CAA_VALUE
    elif [[ "$CAA_TAG" == "iodef" ]]; then
        echo "Enter a URL or email address where CAs should report policy violations"
        echo "For email: \"mailto:security@yourdomain.com\""
        echo "For URL: \"https://yourdomain.com/caa-report\""
        read -p "Enter reporting URL or email: " CAA_VALUE
    else
        read -p "Enter CAA record value: " CAA_VALUE
    fi
    
    PARAMS="DomainName=$DOMAIN_NAME Flags=$CAA_FLAGS Tag=$CAA_TAG Value=$CAA_VALUE"
    ;;
  7)
    echo "DNSSEC deployment requires two steps:"
    echo "1. Creating a KMS key for DNSSEC signing"
    echo "2. Enabling DNSSEC for your hosted zone"
    echo
    echo "Do you want to:"
    echo "1) Create a new KMS key and enable DNSSEC"
    echo "2) Use an existing KMS key and enable DNSSEC"
    read -p "Enter your choice (1-2): " DNSSEC_CHOICE
    
    # Get hosted zone ID
    read -p "Enter your Route 53 hosted zone ID (e.g., Z1234567890ABC): " HOSTED_ZONE_ID
    
    if [[ "$DNSSEC_CHOICE" == "1" ]]; then
      # Deploy KMS key first
      echo "Deploying KMS key for DNSSEC signing..."
      KMS_STACK_NAME="${STACK_NAME_BASE}-dnssec-kms"
      
      # Optional KMS key parameters
      read -p "Enter KMS key alias name [alias/dnssec-${STACK_NAME_BASE}]: " KMS_ALIAS
      KMS_ALIAS=${KMS_ALIAS:-alias/dnssec-${STACK_NAME_BASE}}
      
      deploy_stack "$KMS_STACK_NAME" "dnssec-kms-key.yaml" "KeyAliasName=$KMS_ALIAS"
      
      echo "Waiting for KMS key creation to complete..."
      aws cloudformation wait stack-create-complete --stack-name "$KMS_STACK_NAME"
      
      # Get KMS key ARN
      KMS_KEY_ARN=$(aws cloudformation describe-stacks --stack-name "$KMS_STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='KMSKeyArn'].OutputValue" --output text)
      
      if [[ -z "$KMS_KEY_ARN" ]]; then
        echo "Failed to retrieve KMS key ARN. Please check the stack status and try again."
        exit 1
      fi
      
      echo "KMS key created with ARN: $KMS_KEY_ARN"
    else
      # Use existing KMS key
      read -p "Enter the ARN of your existing KMS key for DNSSEC: " KMS_KEY_ARN
    fi
    
    # Deploy DNSSEC configuration
    RECORD_TYPE="dnssec-configuration"
    read -p "Enter a name for your Key Signing Key [dnssec-key-${STACK_NAME_BASE}]: " KSK_NAME
    KSK_NAME=${KSK_NAME:-dnssec-key-${STACK_NAME_BASE}}
    
    PARAMS="HostedZoneId=$HOSTED_ZONE_ID KeySigningKeyName=$KSK_NAME KMSKeyArn=$KMS_KEY_ARN"
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Create final stack name
if [[ "$RECORD_CHOICE" == "7" ]]; then
  STACK_NAME="$STACK_NAME_BASE-dnssec"
else
  STACK_NAME="$STACK_NAME_BASE-$RECORD_TYPE"
fi

# Deploy the CloudFormation stack using the function
deploy_stack "$STACK_NAME" "$RECORD_TYPE.yaml" "$PARAMS"

## For DNSSEC, provide additional information and complete setup
if [[ "$RECORD_CHOICE" == "7" ]]; then
  echo
  echo "DNSSEC deployment initiated. Waiting for stack to complete..."
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
  
  # Check if DNSSEC is enabled
  DNSSEC_STATUS=$(aws route53 get-dnssec --hosted-zone-id "$HOSTED_ZONE_ID" --query "Status.ServeSignature" --output text 2>/dev/null || echo "DISABLED")
  
  if [[ "$DNSSEC_STATUS" != "SIGNING" ]]; then
    echo "DNSSEC is not yet enabled. Enabling DNSSEC signing..."
    aws route53 enable-hosted-zone-dnssec --hosted-zone-id "$HOSTED_ZONE_ID" > /dev/null
    
    # Wait for DNSSEC to be enabled
    echo "Waiting for DNSSEC to be enabled (this may take a few minutes)..."
    while [[ "$DNSSEC_STATUS" != "SIGNING" ]]; do
      sleep 30
      DNSSEC_STATUS=$(aws route53 get-dnssec --hosted-zone-id "$HOSTED_ZONE_ID" --query "Status.ServeSignature" --output text 2>/dev/null || echo "DISABLED")
      echo "Current DNSSEC status: $DNSSEC_STATUS"
    done
  fi
  
  echo "DNSSEC is enabled. Retrieving DS record information..."
  
  # Get domain name without trailing dot for Route 53 Domains
  DOMAIN_NAME_NO_DOT=${DOMAIN_NAME%?}
  
  # Check if domain is registered with Route 53 Domains
  if aws route53domains get-domain-detail --domain-name "$DOMAIN_NAME_NO_DOT" &>/dev/null; then
    echo "Domain is registered with Route 53 Domains. Adding DS record automatically..."
    
    # Get DS record information
    DS_RECORD_INFO=$(aws route53 get-dnssec --hosted-zone-id "$HOSTED_ZONE_ID" --query "KeySigningKeys[0].DSRecord" --output text)
    
    if [[ -n "$DS_RECORD_INFO" ]]; then
      # Parse DS record
      DS_KEY_TAG=$(echo "$DS_RECORD_INFO" | awk '{print $1}')
      DS_ALGORITHM=$(echo "$DS_RECORD_INFO" | awk '{print $2}')
      DS_DIGEST_TYPE=$(echo "$DS_RECORD_INFO" | awk '{print $3}')
      DS_DIGEST=$(echo "$DS_RECORD_INFO" | awk '{print $4}')
      
      # Deploy DS record template
      DS_STACK_NAME="${STACK_NAME_BASE}-ds-record"
      DS_PARAMS="DomainName=$DOMAIN_NAME_NO_DOT KeyTag=$DS_KEY_TAG Algorithm=$DS_ALGORITHM DigestType=$DS_DIGEST_TYPE Digest=$DS_DIGEST"
      
      deploy_stack "$DS_STACK_NAME" "dnssec-ds-record.yaml" "$DS_PARAMS"
      
      echo "DS record deployment initiated. Waiting for completion..."
      aws cloudformation wait stack-create-complete --stack-name "$DS_STACK_NAME"
      echo "DS record has been added to your domain in Route 53 Domains."
    else
      echo "Could not retrieve DS record information. Please add the DS record manually."
    fi
  else
    echo "Domain is not registered with Route 53 Domains or not accessible."
    echo "Please add the DS record to your domain registrar manually."
    echo
    echo "DS record information:"
    aws route53 get-dnssec --hosted-zone-id "$HOSTED_ZONE_ID" --query "KeySigningKeys[0]" --output json
  fi
  
  echo
  echo "DNSSEC setup is complete for your hosted zone."
  echo "If your domain is not registered with Route 53 Domains, please add the DS record to your domain registrar."
  echo "Note: It may take some time for DNSSEC to fully propagate through the DNS system."
fi






