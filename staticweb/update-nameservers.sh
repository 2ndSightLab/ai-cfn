#!/bin/bash

echo "WARNING: Updating name servers may break email and other services that rely on records defined in the existing hosted zone for this domain."
echo "Are you sure you wnat to continue? (Ctrl-C to exit)"
read ok

# Prompt for domain name and name servers as a comma-separated list
read -p "Enter the domain name (e.g., example.com): " domain_name
read -p "Enter name servers as a comma-separated list (WITHOUT trailing dots, e.g., ns-1234.awsdns-56.org,ns-789.awsdns-12.com,ns-3456.awsdns-78.co.uk,ns-901.awsdns-34.net): " nameservers

# Generate stack name from domain name (replace periods with dashes) and add -nameservers
stack_name=$(echo "$domain_name" | tr '.' '-')"-nameservers"
echo "Using identifier: $stack_name"

# Convert comma-separated string to array
IFS=',' read -ra ns_array <<< "$nameservers"

# Prepare the nameservers parameter for AWS CLI
ns_param=""
for ns in "${ns_array[@]}"; do
    # Add trailing dot if not present
    if [[ ! "$ns" == *. ]]; then
        ns="${ns}."
    fi
    ns_param+="Name=$ns "
done

echo "Updating name servers for domain: $domain_name"
echo "Name servers to be set:"
for ns in "${ns_array[@]}"; do
    echo "  - $ns"
done

# Execute the AWS CLI command
echo "Executing AWS CLI command to update name servers..."
aws route53domains update-domain-nameservers \
    --region us-east-1 \
    --domain-name "$domain_name" \
    --nameservers $ns_param

# Check the command's exit status
if [ $? -eq 0 ]; then
    echo "Name servers updated successfully for $domain_name"
else
    echo "Failed to update name servers for $domain_name"
    echo "Please check that:"
    echo "  - You have the necessary permissions"
    echo "  - The domain exists in your AWS account"
    echo "  - The name servers are in the correct format"
    exit 1
fi

echo "Done! The name servers for $domain_name have been updated."
echo "Note: DNS propagation may take up to 48 hours to complete."
