
#!/bin/bash

echo "scripts/deploy/route53-cloudfront-dns-records.sh"

function deploy_cloudfront_dns_record(){

  local stack="$1"
  local domain_name="$2"
  local hosted_zone_id="$3"
  local cloudfront_domain="$4"
  
  delete_failed_stack_if_exists $stack
  
  aws cloudformation deploy \
    --template-file cfn/route53-cloudfront-dns-record.yaml \
    --stack-name $stack \
    --parameter-overrides \
      DomainName=$domain_name \
      HostedZoneId=$hosted_zone_id \
      CloudFrontDomainName=$cloudfront_domain 
    --no-fail-on-empty-changeset  

   stack_exists $stack $REGION
 
}

read -p "Deploy CloudFront DNS records? (y/n): " DEPLOY_CLOUDFRONT_DNS
if [[ "$DEPLOY_CLOUDFRONT_DNS" == "y" || "$DEPLOY_CLOUDFRONT_DNS" == "Y" ]]; then

deploy_cloudfront_dns_record \
  $CLOUDFRONT_DNS_STACK \
  $DOMAIN_NAME \
  $HOSTED_ZONE_ID \ 
  $CLOUDFRONT_DOMAIN 

  if [ "$DOMAIN_TYPE" == "WWW" ]; then 
  
    deploy_cloudfront_dns_record \
      ${CLOUDFRONT_DNS_STACK}-WWW \
      $DOMAIN_NAME \
      $HOSTED_ZONE_ID \ 
      $CLOUDFRONT_DOMAIN 
  
  fi

  if [ "$DOMAIN_TYPE" == "Wildcard" ]; then 

    deploy_cloudfront_dns_record \
      ${CLOUDFRONT_DNS_STACK}-Wildcard \
      $DOMAIN_NAME \
      $HOSTED_ZONE_ID \ 
      $CLOUDFRONT_DOMAIN 
  fi  

  if [ "$DOMAIN_TYPE" == "Subdomains" ]; then 
  
    echo "Not implemented: Loop through subdomains and deploy each one"
    exit
    
  fi  
  
fi
