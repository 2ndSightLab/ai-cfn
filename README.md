# ai-cfn
CloudFormation templates and scripts created with Amazon Q Developer and a bit of Amazon Bedrock (More or less...see blog posts below).

# Instructions to Deploy a Static Website With a TLS Certificate and CLoudFront distribution

https://medium.com/cloud-security/code-to-deploy-a-website-hosted-in-an-s3-bucket-a-tls-certificate-and-cloudfront-distribution-9cdaf34d6a12

```
# You can run these commands in AWS CloudShell to test (for non-production websites!)
# Use these commands to run the scripts in the AWS account where the website exists
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 deploy.sh
chmod 700 scripts/deploy-tls-cert-validation.sh
./deploy.sh

# Use these commands to run the script to update the name servers where the primary domain exists
# NOTE: If you have existing records set up on existing name servers this can mess things up!
# Use a test domain, not a production domain
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 update-nameservers.sh
./update-nameservers.sh
```

For production website deployments there are many other considerations.

https://medium.com/cloud-security/automating-cybersecurity-metrics-890dfabb6198

# Related posts

AI

https://medium.com/cloud-security/artificial-intelligence-2e97415216c0

Using Q To Deploy CloudFront and a TLS Certificate — First Attempt

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-first-attempt-55acfb5601e3

Using Q To Deploy CloudFront and a TLS Certificate — Second Attempt

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-second-attempt-cd64e591c3c0

Using Q To Deploy CloudFront and a TLS Certificate — Third Time’s The Charm?

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-third-times-the-charm-02107a77accc

Using Q To Deploy CloudFront and a TLS Certificate — S3 Buckets…Maybe

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-s3-buckets-maybe-1787bc521159

Using Q To Deploy CloudFront and a TLS Certificate — S3 Buckets Take 2

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-s3-buckets-take-2-a8b035f369f9

Using Q To Deploy CloudFront and a TLS Certificate — S3 Bucket Policy

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-s3-bucket-policy-180300873954

Using Q To Deploy CloudFront and a TLS Certificate — Cloudfront 🤞

https://2ndsightlab.medium.com/using-q-to-deploy-cloudfront-and-a-tls-certificate-cloudfront-12b876e3f79f

Using Q To Deploy CloudFront and a TLS Certificate — AI doesn’t always write code that works and can’t always fix it’s own errors

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-ai-doesnt-always-write-code-that-works-and-3f368d656320

Using Q To Deploy CloudFront and a TLS Certificate — Yet Another Problem With the ACM Deployment Process

https://medium.com/cloud-security/using-q-to-deploy-cloudfront-and-a-tls-certificate-yet-another-problem-with-the-acm-deployment-f4814f7852ee
