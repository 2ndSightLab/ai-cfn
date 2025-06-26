#!/bin/bash -e

#source all the files in the functions directory
for file in functions/*; do [ -f "$file" ] && source "$file"; done

# We could skip checking these every time but I want to make sure they are right
REGION=$(get_region)
IDENTITY_ARN=$(get_current_identity_arn)
IDENTITY_NAME=$(get_identity_name_from_arn $IDENTITY_ARN)

echo "Enter environment name (prod, dev, test):"
read ENV_NAME

SERVICE_NAME=""
while [ -z "$SERVICE_NAME" ]; do
    echo "Enter the service from which you want to deploy a resource (type help for a list of services):"
    read SERVICE_NAME
    if [ "$SERVICE_NAME" == "help" ]; then
      list_service_names
      SERVICE_NAME=""
    fi
done

RESOURCE_NAME=""
while [ -z "$RESOURCE_NAME" ]; do
    echo "Enter the service from which you want to deploy a resource (type help for a list of services):"
    read RESOURCE_NAME
    if [ "$RESOURCE_NAME" == "help" ]; then
       list_resources_for_service $SERVICE_NAME
       RESOURCE_NAME=""
    fi
done

NAME=""
echo "Is this resource a user, for a specific user, or associated with an application? [y]"
read hasname
if [ "$hasname" == "y" ]; then 
  echo "Enter the name: "
  read NAME
fi

STACK_NAME=$(get_stack_name "$ENV_NAME" "$IDENTITY_NAME" "$SERVICE_NAME" "$RESOURCE_NAME" "$NAME")
CFN_RESOURCE_NAME=$(get_cfn_resource_name "$ENV_NAME" "$SERVICE_NAME" "$RESOURCE_NAME" "$NAME")

echo "ENV: $ENV_NAME"
echo "IDENTITY_ARN: $IDENTITY_ARN"
echo "IDENTITY_NAME: $IDENTITY_NAME"
echo "REGION: $REGION"
echo "STACK_NAME: $STACK_NAME"
echo "CFN_RESOURCE_NAME: $CFN_RESOURCE_NAME"
