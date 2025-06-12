
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

  echo "stack: $1"
  echo "domain_name: $2"
  echo "hosted_zone_id: $3"
  echo "cloudfront_domain: $4"
  echo "region: $5"
  
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

  echo "deploy_cloudfront_dns_record \
    $CLOUDFRONT_DNS_STACK \
    $DOMAIN_NAME \
    $HOSTED_ZONE_ID \ 
    $CLOUDFRONT_DOMAIN \
    $REGION
    
  deploy_cloudfront_dns_record \
    $CLOUDFRONT_DNS_STACK \
    $DOMAIN_NAME \
    $HOSTED_ZONE_ID \ 
    $CLOUDFRONT_DOMAIN \
    $REGION

  if [ "$DOMAIN_TYPE" == "WWW" ]; then 
  
    deploy_cloudfront_dns_record \
      ${CLOUDFRONT_DNS_STACK}-WWW \
      $DOMAIN_NAME \
      $HOSTED_ZONE_ID \ 
      $CLOUDFRONT_DOMAIN \
      $REGION
  
  fi

  if [ "$DOMAIN_TYPE" == "Wildcard" ]; then 

    deploy_cloudfront_dns_record \
      ${CLOUDFRONT_DNS_STACK}-Wildcard \
      $DOMAIN_NAME \
      $HOSTED_ZONE_ID \ 
      $CLOUDFRONT_DOMAIN \
      $REGION
  fi  

  if [ "$DOMAIN_TYPE" == "Subdomains" ]; then 
  
    echo "Not implemented: Loop through subdomains and deploy each one"
    exit
    
  fi  
  
fi
