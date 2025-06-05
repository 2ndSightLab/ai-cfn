#!/bin/bash

# Set the template file path
template_file="cfn/update-nameservers.yaml"

# Prompt for domain name and name servers
read -p "Enter the domain name (e.g., example.com): " domain_name
read -p "Enter nameserver 1 (e.g., ns-1234.awsdns-56.org.): " ns1
read -p "Enter nameserver 2 (e.g., ns-789.awsdns-12.com.): " ns2
read -p "Enter nameserver 3 (e.g., ns-3456.awsdns-78.co.uk.): " ns3
read -p "Enter nameserver 4 (e.g., ns-901.awsdns-34.net.): " ns4

# Generate stack name from domain name (replace periods with dashes) and add -nameservers
stack_name=$(echo "$domain_name" | tr '.' '-')"-nameservers"
echo "Using stack name: $stack_name"

# Check if the template file exists
if [ ! -f "$template_file" ]; then
  echo "Error: CloudFormation template file '$template_file' not found in the current directory."
  exit 1
fi

# Format domain name for hosted zone lookup (remove trailing dot if present)
lookup_domain=${domain_name%.}

echo "Looking up hosted zone ID for domain: $lookup_domain"

# Look up the hosted zone ID
hosted_zone_id=$(aws route53 list-hosted-zones-by-name --dns-name "$lookup_domain" --query 'HostedZones[?Name==`'$lookup_domain'.`].Id' --output text)

# Check if hosted zone was found
if [ -z "$hosted_zone_id" ]; then
  echo "Error: No hosted zone found for domain $lookup_domain"
  exit 1
fi

# Extract the zone ID from the full string (remove /hostedzone/ prefix)
hosted_zone_id=${hosted_zone_id#/hostedzone/}

echo "Found hosted zone ID: $hosted_zone_id"

# Deploy the CloudFormation template
echo "Deploying CloudFormation stack: $stack_name"
aws cloudformation deploy \
  --template-file "$template_file" \
  --stack-name "$stack_name" \
  --parameter-overrides \
    DomainName="$domain_name" \
    HostedZoneId="$hosted_zone_id" \
    NameServer1="$ns1" \
    NameServer2="$ns2" \
    NameServer3="$ns3" \
    NameServer4="$ns4" \
  --capabilities CAPABILITY_IAM

# Check deployment status
if [ $? -eq 0 ]; then
  echo "CloudFormation stack deployment initiated successfully."
  echo "You can check the status with: aws cloudformation describe-stacks --stack-name $stack_name"
else
  echo "CloudFormation stack deployment failed."
fi

