#/bin/bash

# Prompt for the domain name
read -p "Enter your domain name (e.g., radicalsoftware.com): " DOMAIN_NAME

# Create stack name by replacing dots with hyphens and adding -google-mx
STACK_NAME=$(echo $DOMAIN_NAME | tr '.' '-')-google-mx

# Deploy the CloudFormation stack
echo "Deploying stack: $STACK_NAME for domain: $DOMAIN_NAME"
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file cfn/google-mx.yanml \
  --parameter-overrides DomainName=$DOMAIN_NAME

# Monitor stack creation
echo "Deployment initiated. You can check the status of your stack with:"
echo "aws cloudformation describe-stacks --stack-name \"$STACK_NAME\""

