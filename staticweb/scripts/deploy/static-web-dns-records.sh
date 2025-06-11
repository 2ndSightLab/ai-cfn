#!/bin/bash -e

echo "scripts/deploy/static-web-dns-records.sh"

# Route 53 Hosted Zone 
read -p "Deploy Route 53 static web dns records? (y/n): " DEPLOY_WEB_DNS_RECORDS
if [[ "$DEPLOY_WEB_DNS_RECORDS" == "y" || "$DEPLOY_WEB_DNS_RECORDS" == "Y" ]]; then

  delete_failed_stack_if_exists $STATIC_WEB_DNS_RECORDS_STACK $REGION

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
  read -p "Enter your choice (1-4) [2]: " DOMAIN_TYPE_CHOICE
  DOMAIN_TYPE_CHOICE=${DOMAIN_TYPE_CHOICE:-2}
  
  case $DOMAIN_TYPE_CHOICE in
      1) DOMAIN_TYPE="Basic" ;;
      2) DOMAIN_TYPE="WWW" ;;
      3) DOMAIN_TYPE="Wildcard" ;;
      4) 
          DOMAIN_TYPE="Subdomains"
          echo ""
          echo "Enter fully qualified subdomains, separated by commas"
          echo "Example: api.${DOMAIN_NAME},blog.${DOMAIN_NAME},shop.${DOMAIN_NAME}"
          read -p "Subdomains: " CUSTOM_SUBDOMAINS
          ;;
      *) 
          echo "Invalid choice. Exit."
          exit
          ;;
  esac

  echo "Deploying Route 53 hosted zone for $DOMAIN_NAME..."
  aws cloudformation deploy \
    --region $REGION \
    --template-file cfn/hosted-zone.yaml \
    --stack-name $STATIC_WEB_DNS_RECORDS_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
      DomainType=$DOMAIN_TYPE \
      CreateS3Records=true \
    --no-fail-on-empty-changeset
fi

stack_exists $STATIC_WEB_DNS_RECORDS_STACK $REGION

# Get the domain name from the stack outputs
DOMAIN_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STATIC_WEB_DNS_RECORDS_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='DomainName'].OutputValue" \
    --output text)

DOMAIN_TYPE=$(aws cloudformation describe-stacks \
    --stack-name $STATIC_WEB_DNS_RECORDS_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='DomainType'].OutputValue" \
    --output text)
    
echo "Domain Name: $DOMAIN_NAME"  
echo "Domain Type: $DOMAIN_TYPE"
