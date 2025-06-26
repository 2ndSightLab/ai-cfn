#!/bin/bash -e

echo "Select an action:"
echo "1. Create role to assume with MFA"
echo "2. Add a policy to a user to allow them to assume the role."
read action

if [ "$action" == "1" ]; then
   ./create-role-to-asume-with-mfa.sh
else
   ./create-poicy-to-assume-role-with-mfa.sh
fi
