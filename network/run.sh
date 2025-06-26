#!/bin/bash

echo "Enter the name of the environment for which you want to deploy a shared network:"
read ENV_NAME

user=$(aws sts get-caller-identity --query User.Arn --output text | cut -d '/' -f 2)

echo "Enter VPC_CIDR (e.g. 10.20.30.0/23):"
read VPC_CIDR

VPC_NAME="${ENV_NAME}-VPC"
ENABLE_DNS_SUPPORT="true"
ENABLE_DNS_HOSTNAMES="false"
TEMPLATE_FILE="cfn/vpc.yaml"
STACK_NAME="$VPC_NAME"

IGW_NAME="${ENV_NAME}-IGW"

