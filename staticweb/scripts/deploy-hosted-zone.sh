#!/bin/bash -e

source scripts/check-name-servers.sh

echo "deploy-hosted-zone.sh"

# Domain name
read -p "Domain name (e.g., example.com): " DOMAIN_NAME
while [[ -z "$DOMAIN_NAME" ]]; do
  echo "Domain name cannot be empty."
  read -p "Domain name (e.g., example.com): " DOMAIN_NAME
done

# Route 53 Hosted Zone 
read -p "Deploy Route 53 hosted zone? (y/n): " DEPLOY_HOSTED_ZONE
if [[ "$DEPLOY_HOSTED_ZONE" == "y" || "$DEPLOY_HOSTED_ZONE" == "Y" ]]; then
  if stack_exists $HOSTED_ZONE_STACK; then
    echo "Hosted zone stack already exists. Updating..."
  else
    echo "Creating new hosted zone stack..."
  fi

  delete-failed-stack-if-exists $HOSTED_ZONE_STACK $REGION
  
  echo "Deploying Route 53 hosted zone for $DOMAIN_NAME..."
  aws cloudformation deploy \
    --region $REGION
    --template-file cfn/hosted-zone.yaml \
    --stack-name $HOSTED_ZONE_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset
fi

stack_exists $HOSTED_ZONE_STACK $REGION

# Get the Hosted Zone ID from the stack outputs
HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='HostedZoneId'].OutputValue" \
    --output text)
  
NAME_SERVERS=$(aws cloudformation describe-stacks \
    --stack-name $HOSTED_ZONE_STACK \
    --query "Stacks[0].Outputs[?OutputKey=='NameServers'].OutputValue" \
    --output text
    --region $REGION)
  
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
echo "IMPORTANT: Update your domain's name servers with your registrar to point to:"
echo "$NAME_SERVERS"
echo "DNS propagation may take up to 48 hours."

echo -e "\nEnter to continue after you have upated the records."
read ok

check-name_servers $NAME_SERVERS

