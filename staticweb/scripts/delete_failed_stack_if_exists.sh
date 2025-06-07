#!/bin/bash
echo "delete_failed_stack_if_exists.sh"

delete_failed_stack_if_exists() {
  local stack_name=$1
  if aws cloudformation describe-stacks --stack-name $stack_name &>/dev/null; then
  
    echo "Checking for existing CloudFormation stack..."
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "STACK_NOT_FOUND")
    
    if [[ "$STACK_STATUS" == *"FAILED"* || "$STACK_STATUS" == *"ROLLBACK_COMPLETE"* ]]; then
        echo "Check if status exists in a failed state"
        echo "Stack $TLS_CERTIFICATE_STACK exists in a failed state ($STACK_STATUS)."
        echo "Deleting it before redeployment..."
        aws cloudformation delete-stack --stack-name $stack_name
        
        echo "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name $TLS_CERTIFICATE_STACK
        echo "Stack deletion complete."
     fi
  fi
}
