#!/bin/bash

stack_exists() {
  local stack_name="$1"
  local region="$2"

  if [ "$region" == "" ]; then
     echo "Region not set checking to see if $stack_name exists"; exit
  fi

  echo "Check stack_exists: $stack_name $region"
  
  if aws cloudformation describe-stacks --stack-name $stack_name --region $region &>/dev/null; then
  
    # Check if stack exists in a failed state
    echo "Checking to see if stack exists in stack_exists function"
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --region $region --output text 2>/dev/null || echo "STACK_NOT_FOUND")
    return 0  # Stack exists
       
  else
    return 1  # Stack does not exist
  fi
}
