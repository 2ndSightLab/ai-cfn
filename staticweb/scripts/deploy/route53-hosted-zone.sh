#!/bin/bash -e

#Note: DomainType and Subdomains are saved in outputs for use in other stacks


source scripts/functions/check-name-servers.sh

echo "scripts/deploy/route53-hosted-zone.sh"

CustomSubdomains=''

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
  read -p "Enter your choice (1-4) [2]: " DOMAIN_TYPE_CHOICE
  DOMAIN_TYPE_CHOICE=${DOMAIN_TYPE_CHOICE:-2}
  
  case $DOMAIN_TYPE_CHOICE in
      1) DOMAIN_TYPE="Basic" ;;
      2) DOMAIN_TYPE="WWW" ;;
      3) DOMAIN_TYPE="Wildcard" ;;
      4) 
          DOMAIN_TYPE="Subdomain";;
      *) 
          echo "Invalid choice. Exit."
          exit
          ;;
  esac


  aws cloudformation deploy \
        --region $REGION \
        --template-file cfn/route53-hosted-zone.yaml \
        --stack-name $HOSTED_ZONE_STACK \
        --parameter-overrides \
          DomainName=$DOMAIN_NAME \
          DomainType=$DOMAIN_TYPE \
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

CUSTOM_SUBDOMAINS=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='CustomSubdomains'].OutputValue" \
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

echo "Domain Name: $DOMAIN_NAME"  
echo "Domain Type: $DOMAIN_TYPE"  
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
echo "Custom Subdomains: $CUSTOM_SUBDOMAINS"
echo "Name Servers:"
echo "$NAME_SERVERS"

if [[ "$DEPLOY_HOSTED_ZONE" == "y" || "$DEPLOY_HOSTED_ZONE" == "Y" ]]; then
  echo -e "\nIMPORTANT:"

  if [[ "DOMAIN_TYPE" == "SUBDOMAIN" ]]; then
     parent_domain=$(extract_primary_domain $DOMAIN_NAME)
     parent_hosted_zone_id=$(aws route53 list-hosted-zones-by-name --dns-name $parent_domain)

     echo "Add an NS record for the above name servers in the hosted zone ID: $parent_hosted_zone for $parent_domain"

     echo -e "\nEnter to continue after you have upated the records."
     read ok
  else
    echo "Update your domain's name servers with your registrar to point to the above name servers before proceeding."
    echo "Refer to the instructions in the github repository and related blogs for more information."
    echo "DNS propagation may take up to 48 hours."
    echo -e "\nEnter to continue after you have upated the records."
    read ok
fi
#this doesn't work in cloudshell because dig is not installed.
#I wonder why ? ;^)
#check_name_servers $NAME_SERVERS
