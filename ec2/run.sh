#!/bin/bash -e

#temp for testing
REGION=""
AMI_ID=""

#get the latest ami id for the selected OS
scripts/get-latest-ami.sh

if [ "$REGION" == "" ]; then echo "Error: Region is not set in get-latest-ami.sh"; exit; fi
if [ "$AMI_ID" == "" ]; then echo "Error: AMI ID is not set in get-latest-ami.sh"; exit; fi

#get the instance type to use when launching the instance
source scripts/get-ec2-instance-type.sh

