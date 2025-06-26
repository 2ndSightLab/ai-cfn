#!/bin/bash -e

# Get the current user's ARN
DEPLOY_USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)

# Extract the username from the ARN
# Handle different ARN formats:
# - User ARNs: arn:aws:iam::123456789012:user/username
# - Role ARNs: arn:aws:iam::123456789012:role/rolename
# - Root user: arn:aws:iam::123456789012:root
if [[ $DEPLOY_USER_ARN == *":root" ]]; then
    # For root user
    DEPLOY_USER_NAME="root"
else
    # For IAM users and roles
    DEPLOY_USER_NAME=$(echo $DEPLOY_USER_ARN | rev | cut -d'/' -f1 | rev)
fi

# Check if the template file exists
TEMPLATE_FILE="cfn/iam-user-with-secret.yaml"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Prompt for environment name until provided
ENV_NAME=""
while [ -z "$ENV_NAME" ]; do
    read -p "Enter environment name (e.g., dev, test, prod): " ENV_NAME
done

# Prompt for username until provided
USERNAME=""
while [ -z "$USERNAME" ]; do
    read -p "Enter username for the IAM user: " USERNAME
done

# Prompt for KMS key ARN until a valid value is provided
KMS_KEY_ARN=""
while [ -z "$KMS_KEY_ARN" ] || ! [[ $KMS_KEY_ARN =~ ^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$ ]]; do
    read -p "Enter KMS key ARN (format: arn:aws:kms:region:account-id:key/key-id): " KMS_KEY_ARN
    
    # Show error message if input is not empty but invalid
    if [ ! -z "$KMS_KEY_ARN" ] && ! [[ $KMS_KEY_ARN =~ ^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$ ]]; then
        echo "Error: Invalid KMS key ARN format. Please try again."
        KMS_KEY_ARN=""
    fi
done

# Set the stack name based on environment, deployer, and IAM username
# Ensure the stack name only contains valid characters (alphanumeric and hyphens)
# and starts with an alphabetic character
STACK_NAME="${ENV_NAME}-${DEPLOY_USER_NAME}-iam-user-${USERNAME}"

# Display all values in KEY: VALUE format before deployment
echo "Deployment Configuration:"
echo "Deploying User: $DEPLOY_USER_NAME"
echo "Environment: $ENV_NAME"
echo "IAM Username: $USERNAME"
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo "KMS Key ARN: $KMS_KEY_ARN"
echo "Additional Principal ARN: $DEPLOY_USER_ARN"
echo "-----------------------------------"
echo "Deploying CloudFormation stack..."

# Deploy the CloudFormation stack using deploy command
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file $TEMPLATE_FILE \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Username=$USERNAME \
    KmsKeyArn=$KMS_KEY_ARN \
    AdditionalPrincipalArn=$DEPLOY_USER_ARN

# Check if deployment was successful
if [ $? -eq 0 ]; then
  echo "Stack deployment completed successfully!"
  
  # Get outputs from the stack
  SECRET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='SecretName'].OutputValue" --output text)
  
  echo "Environment: $ENV_NAME"
  echo "Created IAM user: $USERNAME"
  echo "Additional access granted to: $DEPLOY_USER_ARN"
else
  echo "Stack deployment failed. Check the AWS CloudFormation console for details."
fi




