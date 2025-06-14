
#!/bin/bash

echo "scripts/deploy/route53-cloudfront-dns-records.sh"

echo "REGION: $REGION"
echo "CLOUDFRONT_DOMAIN: $CLOUDFRONT_DOMAIN"

function deploy_cloudfront_dns_record(){

  stack="$1"
  domain_name="$2"
  hosted_zone_id="$3"
  cloudfront_domain="$4"
  region="$5"

  delete_failed_stack_if_exists $stack $region
  
  aws cloudformation deploy \
    --template-file cfn/route53-cloudfront-dns-record.yaml \
    --stack-name $stack \
    --parameter-overrides \
      DomainName=$domain_name \
      HostedZoneId=$hosted_zone_id \
      CloudFrontDomainName=$cloudfront_domain \
    --no-fail-on-empty-changeset \
    --region $region 

   stack_exists $stack $region
 
}

read -p "Deploy CloudFront DNS records? (y/n): " DEPLOY_CLOUDFRONT_DNS
if [[ "$DEPLOY_CLOUDFRONT_DNS" == "y" || "$DEPLOY_CLOUDFRONT_DNS" == "Y" ]]; then

  if [ "$DOMAIN_NAME" == "" ]; then
     echo "DOMAIN_NAME is not set: $DOMAIN_NAME"; exit
  fi
  
  if [ "$HOSTED_ZONE_ID" == "" ]; then
     echo "HOSTED_ZONE_ID is not set: $HOSTED_ZONE_ID"; exit
  fi
  
  if [ "$CLOUDFRONT_DOMAIN" == "" ]; then
     echo "CLOUDFRONT_DOMAIN is not set: $CLOUDFRONT_DOMAIN"; exit
  fi

  if [ "$REGION" == "" ]; then
     echo "REGION is not set: $REGION"
  fi
  
  deploy_cloudfront_dns_record \
    "$CLOUDFRONT_DNS_STACK" \
    "$DOMAIN_NAME" \
    "$HOSTED_ZONE_ID" \
    "$CLOUDFRONT_DOMAIN" \
    "$REGION"

  if [ "$DOMAIN_TYPE" == "WWW" ]; then 
  
    deploy_cloudfront_dns_record \
      "$CLOUDFRONT_DNS_STACK" \
      "$DOMAIN_NAME" \
      "$HOSTED_ZONE_ID" \
      "$CLOUDFRONT_DOMAIN" \
      "$REGION"
  
  fi

  if [ "$DOMAIN_TYPE" == "Wildcard" ]; then 

    deploy_cloudfront_dns_record \
      "$CLOUDFRONT_DNS_STACK" \
      "$DOMAIN_NAME" \
      "$HOSTED_ZONE_ID" \
      "$CLOUDFRONT_DOMAIN" \
      "$REGION"
  fi  

  if [ "$DOMAIN_TYPE" == "Subdomains" ]; then 
  
    #currently assumes there is only one custom domain name
    deploy_cloudfront_dns_record \
      "$CLOUDFRONT_DNS_STACK" \
      "$CUSTOM_SUBDOMAINS" \
      "$HOSTED_ZONE_ID" \
      "$CLOUDFRONT_DOMAIN" \
      "$REGION"
    
  fi  
  
fi
