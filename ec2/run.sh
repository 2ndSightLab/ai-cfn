#!/bin/bash -e

#temp for testing
REGION=""
AMI_ID=""
INSTANCE_TYPE=""

#get the latest ami id for the selected OS
source scripts/get-latest-ami.sh

#get the instance type to use when launching the instance
source scripts/get-ec2-instance-type.sh

echo "REGION: $REGION"
echo "AMI_ID: $AMI_ID"
echo "INSTANCE_TYPE: $INSTANCE_TYPE"
