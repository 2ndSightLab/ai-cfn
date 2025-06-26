#!/bin/bash -e

# Get the username of the person deploying the template (extract just the name, not the full ARN)
DEPLOY_USER_NAME=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d '/' -f 2 | cut -d ':' -f 2)
echo "Deploying as user: $DEPLOY_USER_NAME"

# Check if the template file exists
TEMPLATE_FILE="cfn/iam-user-with-secret.yaml"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Prompt for environment name until it's provided
ENV_NAME=""
while [ "$ENV_NAME" == "" ]; do
    read -p "Enter environment name (e.g., dev, test, prod): " ENV_NAME
done

# Prompt for username until it's provided
USERNAME=""
while [ "$USERNAME" == "" ]; do
    read -p "Enter username for the IAM user: " USERNAME
done

# Set the stack name based on environment, deployer, and IAM username
STACK_NAME="$ENV_NAME-$DEPLOY_USER_NAME-iam-user-$USERNAME"
echo "Stack name will be: $STACK_NAME"

# Prompt for KMS key ARN until it's provided
KMS_KEY_ARN=""
while [ "$KMS_KEY_ARN" == "" ]; do
    read -p "Enter KMS key ARN for secret encryption: " KMS_KEY_ARN
done

echo "Stack parameters:"
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo "Environment: $ENV_NAME"
echo "Deploying User: $DEPLOY_USER_NAME"
echo "IAM Username: $USERNAME"
echo "KMS Key ARN: $KMS_KEY_ARN"
echo

# Simple confirmation before deploying
echo "Deploy stack? (Ctrl-c to exit, any other key to continue)"; read ok

# Deploy the CloudFormation stack
echo "Deploying stack..."
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameter-overrides \
        Username="$USERNAME" \
        KmsKeyArn="$KMS_KEY_ARN" \
    --capabilities CAPABILITY_NAMED_IAM

# Get stack outputs
echo "Deployment completed. Retrieving outputs..."
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs" \
    --output table

echo "User $USERNAME has been successfully deployed!"
echo "The password is stored in AWS Secrets Manager with the same name as the username."
echo "The user will be required to change their password on first login."


