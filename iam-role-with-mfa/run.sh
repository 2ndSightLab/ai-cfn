#!/bin/bash -e

echo "Select an action:"
echo "1. Create role to assume with MFA"
echo "2. Add a policy to a user to allow them to assume the role."
read action

if [ "$action" == "1" ]; then
   ./create-role-that-requires-mfa-to-assume.sh
else
   ./create-iam-policy-to-assume-role-with-mfa.sh
fi
