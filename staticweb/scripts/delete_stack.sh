#!/bin/bash

delete_stack() {
  local stack_name=$1
  
  # Delete the stack
  echo "Deleting stack $stack_name..."
  aws cloudformation delete-stack --stack-name $stack_name

  # Wait for the stack deletion to complete
  echo "Waiting for stack $stack_name deletion to complete..."
  aws cloudformation wait stack-delete-complete --stack-name $stack_name

  echo "Stack $stack_name has been deleted successfully."
}
