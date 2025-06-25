#!/bin/bash -e

#temp for testing
REGION=us-east-2
AMI_ID=""

#get the latest ami id for the selected OS
scripts/get-latest-ami.sh

#get the instance type to use when launching the instance
source scripts/get-ec2-instance-type.sh

