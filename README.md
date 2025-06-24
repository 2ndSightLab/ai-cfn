# ai-cfn
CloudFormation templates and scripts created with Amazon Q Developer and a bit of Amazon Bedrock (Kind of...see blog posts).

# Related posts on writing code with AI

Artifical Intelligence:
https://medium.com/cloud-security/artificial-intelligence-2e97415216c0

Note: These scripts are for testing only. Production deployments have other considerations
as explained in these blog posts:
https://medium.com/cloud-security/automating-cybersecurity-metrics-890dfabb6198

# Instructions to Deploy a Static Website With a TLS Certificate and CloudFront distribution

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

# Instructions to Deploy DNS records:

```
# Run this scirpt and select the type of DNS record you want to deploy
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/dns
chmod 700 deploy.sh
./deploy.sh

# For DNSSEC you will need to deploy a KMS key which you may opt to deploy
# in a separate account, making sure the key can be used in the account
# where DNSSEC is configured.
https://github.com/2ndSightLab/ai-cfn/blob/main/dns/cfn/dnssec-kmskey.yaml
```


# Instructions to use EC2 get_latest_ami.sh:

```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/ec2/scripts
chmod 700 ai-cfn/ec2/scripts/get-latest-ami.sh
./ai-cfn/ec2/scripts/get-latest-ami.sh
