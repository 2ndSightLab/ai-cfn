#!/bin/bash
echo "delete-failed-stack-if-exists.sh"

delete_failed_stack_if_exists() {
  local stack_name="$1"
  local region="$2"
  
  if [ "$region" == "" ]; then
     echo "Region not set checking to see if $stack_name exists in a failed state and needs to be deleted"; exit
  fi
  

  if [ "$region" == "" ]; then region="us-east-1"; fi
  
  if aws cloudformation describe-stacks --stack-name $stack_name --region $region &>/dev/null; then
  
    echo "Checking for existing CloudFormation stack..."
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --region $region --output text 2>/dev/null || echo "STACK_NOT_FOUND")
    
    if [[ "$STACK_STATUS" == *"FAILED"* || "$STACK_STATUS" == *"ROLLBACK_COMPLETE"* ]]; then
        echo "Check if status exists in a failed state"
        echo "Stack $stack_name exists in a failed state ($STACK_STATUS)."
        echo "Deleting it before redeployment..."
        aws cloudformation delete-stack --stack-name $stack_name --region $region
        
        echo "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $region
        echo "Stack deletion complete."
     fi
  fi
}
