#!/bin/bash

delete_stack() {
  local stack_name=$1
  local region="$2"

  echo "scripts/functions/delete-stack.sh $stack_name $region"
  
  if [ "$region" == "" ]; then
     echo "Region not set deleting stack $stack_name"; exit
  fi
  
  # Check if the stack exists
  if aws cloudformation describe-stacks --stack-name $stack_name --region $region &>/dev/null; then
    # Delete the stack
    echo "Deleting stack $stack_name..."
    aws cloudformation delete-stack --stack-name $stack_name --region $region

    # Wait for the stack deletion to complete
    echo "Waiting for stack $stack_name deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $region

    echo "Stack $stack_name has been deleted successfully."
  fi
}
