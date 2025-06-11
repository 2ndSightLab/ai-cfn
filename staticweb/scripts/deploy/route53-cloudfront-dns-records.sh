
#!/bin/bash

echo "scripts/deploy/route53-cloudfront-dns-records.sh"

read -p "Deploy CloudFront DNS records? (y/n): " DEPLOY_CLOUDFRONT_DNS
if [[ "$DEPLOY_CLOUDFRONT_DNS" == "y" || "$DEPLOY_CLOUDFRONT_DNS" == "Y" ]]; then

  delete_failed_stack_if_exists $CLOUDFRONT_DNS_STACK $REGION
  
  aws cloudformation deploy \
    --template-file cfn/cloudfront-dns-records.yaml \
    --stack-name $CLOUDFRONT_DNS_STACK \
    --parameter-overrides \
      DomainName=$DOMAIN_NAME \
      HostedZoneId=$HOSTED_ZONE_ID \
      CloudFrontDomainName=$CLOUDFRONT_DOMAIN \
      DomainType=$DOMAIN_TYPE \
    --no-fail-on-empty-changeset
    
  stack_exists $CLOUDFRONT_DNS_STACK $REGION $REGION

fi
