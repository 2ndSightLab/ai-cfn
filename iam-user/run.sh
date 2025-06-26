#!/bin/bash

# Set variables
STACK_NAME="iam-user-with-secret"
TEMPLATE_FILE="iam-user-with-secret.yaml"
USERNAME="new-iam-user"  # Change this to your desired username
KMS_KEY_ARN="arn:aws:kms:region:account-id:key/key-id"  # Replace with your actual KMS key ARN

# Get the current user's ARN
CURRENT_USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)

echo "Current user ARN: $CURRENT_USER_ARN"
echo "Deploying CloudFormation stack with additional access for current user..."

# Deploy the CloudFormation stack
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://$TEMPLATE_FILE \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=Username,ParameterValue=$USERNAME \
    ParameterKey=KmsKeyArn,ParameterValue=$KMS_KEY_ARN \
    ParameterKey=AdditionalPrincipalArn,ParameterValue=$CURRENT_USER_ARN

echo "Stack creation initiated. Waiting for stack to complete..."

# Wait for the stack to complete
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

if [ $? -eq 0 ]; then
  echo "Stack creation completed successfully!"
  
  # Get outputs from the stack
  SECRET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='SecretName'].OutputValue" --output text)
  
  echo "Created IAM user: $USERNAME"
  echo "Secret name: $SECRET_NAME"
  echo "Additional access granted to: $CURRENT_USER_ARN"
else
  echo "Stack creation failed. Check the AWS CloudFormation console for details."
fi



