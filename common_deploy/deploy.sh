#!/bin/bash -e

#source all the files in the functions directory
for file in ../functions/*; do [ -f "$file" ] && source "$file"; done

# We could skip checking these every time but I want to make sure they are right
REGION=$(get_region)
IDENTITY_ARN=$(get_current_identity_arn)
IDENTITY_NAME=$(get_current_identity_arn)

echo "Enter environment name (prod, dev, test):
read ENV_NAME

Echo "Enter the service from which you want to deploy a resource:"
read SERVICE_NAME

echo "Enter the type of resource you would like to deploy"
read RESOURCE_NAME


echo "Is this resource a user, for a specific user, or associated with an application? [y]"
read hasname
if [ "$hasname" == "y" ]; then 
  echo "Enter the name: "
  read NAME
else
  NAME=""
fi

STACK_NAME=$(get_stack_name $ENV_NAME, $IDENTITY_NAME, $SERVICE, $RESOURCE, $NAME)
CFN_RESOURCE_NAME=$(get_cfn_resource_name $ENV_NAME, $SERVICE, $RESOURCE, $NAME)

echo "ENV: $ENV_NAME"
echo "IDENTITY_ARN: $IDENTITY_ARN"
echo "IDENTITY_NAME: $IDENTITY_NAME"
echo "REGION: $REGION"
echo "STACK_NAME: $STACK_NAME"
echo "CFN_RESOURCE_NAME: $CFN_RESOURCE_NAME"
