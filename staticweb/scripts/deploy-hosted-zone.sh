#!/bin/bash -e

source scripts/check-name-servers.sh

echo "deploy-hosted-zone.sh"

# Route 53 Hosted Zone 
read -p "Deploy Route 53 hosted zone? (y/n): " DEPLOY_HOSTED_ZONE
if [[ "$DEPLOY_HOSTED_ZONE" == "y" || "$DEPLOY_HOSTED_ZONE" == "Y" ]]; then

  delete_failed_stack_if_exists $HOSTED_ZONE_STACK $REGION

  # Domain name
  read -p "Domain name (e.g., example.com): " DOMAIN_NAME
  while [[ -z "$DOMAIN_NAME" ]]; do
    echo "Domain name cannot be empty."
    read -p "Domain name (e.g., example.com): " DOMAIN_NAME
  done

  # Ask for domain type type
  echo "Select domain type:"
  echo "1) Basic (domain only)"
  echo "2) WWW (domain + www subdomain)"
  echo "3) Wildcard (domain + *.domain)"
  echo "4) Custom subdomains"
  read -p "Enter your choice (1-4) [2]: " CERT_TYPE_CHOICE
  DOMAIN_TYPE_CHOICE=${DOMAIN_TYPE_CHOICE:-2}
  
  case $DOMAIN_TYPE_CHOICE in
      1) DOMAIN_TYPE="Basic" ;;
      2) DOMAIN_TYPE="WWW" ;;
      3) DOMAIN_TYPE="Wildcard" ;;
      4) 
          DOMAIN_TYPE="CustomSubdomains"
          echo ""
          echo "Enter fully qualified subdomains, separated by commas"
          echo "Example: api.${DOMAIN_NAME},blog.${DOMAIN_NAME},shop.${DOMAIN_NAME}"
          read -p "Subdomains: " CUSTOM_SUBDOMAINS
          ;;
      *) 
          echo "Invalid choice. Defaulting to WWW certificate."
          DOMAIN_TYPE="WWW"
          ;;
  esac

  echo "Deploying Route 53 hosted zone for $DOMAIN_NAME..."
  aws cloudformation deploy \
    --region $REGION
    --template-file cfn/hosted-zone.yaml \
    --stack-name $HOSTED_ZONE_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
      DomainType=$DOMAIN_TYPE
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
fi

stack_exists $HOSTED_ZONE_STACK $REGION

# Get the domain name from the stack outputs
DOMAIN_NAME=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='DomainName'].OutputValue" \
    --output text)

DOMAIN_TYPE=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='DomainType'].OutputValue" \
    --output text)
    
# Get the Hosted Zone ID from the stack outputs
HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='HostedZoneId'].OutputValue" \
    --output text)
  
NAME_SERVERS=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='NameServers'].OutputValue" \
    --output text \
    --region $REGION)
  
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
echo "IMPORTANT: Update your domain's name servers with your registrar to point to:"
echo "$NAME_SERVERS"
echo "DNS propagation may take up to 48 hours."

echo -e "\nEnter to continue after you have upated the records."
read ok

#this doesn't work in cloudshell because dig is not installed.
#I wonder why ? ;^)
#check_name_servers $NAME_SERVERS

