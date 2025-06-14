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
echo "Which type of DNS record do you want to deploy?"
echo "1) Google DKIM"
echo "2) Google MAIL"
echo "3) Google SPF"
echo "4) TXT"
echo "5) CNAME"
echo "6) CAA"
read -p "Enter your choice (1-6): " RECORD_CHOICE

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
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Create final stack name
STACK_NAME="$STACK_NAME_BASE-$RECORD_TYPE"

# Deploy the CloudFormation stack using the function
deploy_stack "$STACK_NAME" "$RECORD_TYPE.yaml" "$PARAMS"





