#!/bin/bash

# Prompt for domain name and name servers as a comma-separated list
read -p "Enter the domain name (e.g., example.com): " domain_name
read -p "Enter name servers as a comma-separated list (WITHOUT trailing dots, e.g., ns-1234.awsdns-56.org,ns-789.awsdns-12.com,ns-3456.awsdns-78.co.uk,ns-901.awsdns-34.net): " nameservers

# Generate identifier from domain name (replace periods with dashes) and add -nameservers
# If domain starts with a number, prepend "s-"
if [[ $domain_name =~ ^[0-9] ]]; then
    identifier="s-$(echo "$domain_name" | tr '.' '-')"
else
    identifier=$(echo "$domain_name" | tr '.' '-')
fi
identifier="${identifier}-nameservers"
echo "Using identifier: $identifier"

# Convert comma-separated string to array and trim whitespace
IFS=',' read -ra ns_array_raw <<< "$nameservers"
ns_array=()

# Trim whitespace from each nameserver
for ns in "${ns_array_raw[@]}"; do
    # Trim leading and trailing whitespace
    trimmed=$(echo "$ns" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    ns_array+=("$trimmed")
done

# Build JSON format for nameservers parameter
nameservers_json="["
for i in "${!ns_array[@]}"; do
    # Add trailing dot if not present
    ns="${ns_array[$i]}"
    if [[ ! "$ns" == *. ]]; then
        ns="${ns}."
    fi
    
    # Add to JSON
    nameservers_json+="{\"Name\":\"$ns\"}"
    
    # Add comma if not the last element
    if [ $i -lt $(( ${#ns_array[@]} - 1 )) ]; then
        nameservers_json+=","
    fi
done
nameservers_json+="]"

echo "Updating name servers for domain: $domain_name"
echo "Name servers to be set:"
for ns in "${ns_array[@]}"; do
    if [[ ! "$ns" == *. ]]; then
        ns="${ns}."
    fi
    echo "  - $ns"
done

# Execute the AWS CLI command
echo "Executing AWS CLI command to update name servers..."
echo "Command: aws route53domains update-domain-nameservers --region us-east-1 --domain-name \"$domain_name\" --nameservers '$nameservers_json'"
aws route53domains update-domain-nameservers \
    --region us-east-1 \
    --domain-name "$domain_name" \
    --nameservers "$nameservers_json"

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
