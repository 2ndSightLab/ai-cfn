# ai-cfn
CloudFormation templates and scripts created with Amazon Q Developer and a bit of Amazon Bedrock (Kind of...see blogposts). 

# About writing code with AI

Artifical Intelligence:

https://medium.com/cloud-security/artificial-intelligence-2e97415216c0

# Deploy Anything!

I'm scrapping the scripts below to focus on this one. I used AI (in part) to write deterministic code.

* Choose an environment name (like dev, qa, prod, or however you want to define trust boundaries)
* Enter the service name of the resource you want to deploy (e.g. Organizations)
* Enter the resource type (e.g. Account)
* If a cloudformation template to deploy the resource deos not exist, it will be created
* If the script to deploy the template does not exist, it will be created
* You will be prompted to enter each possible value (some are not really applicable)
* Then the values you set will be passed to the temlpate to deploy the resource
* It is not yet designed to handle sub types and have only tested certain parameter types
* The AI brain went in circles a bunch of times and I had to fix problems myself on this one.
* ^^ I asked multiple AI chatbots ^^
* Your resrouces and stacks will all have a nice naming convention too!

https://medium.com/cloud-security/automating-cybersecurity-metrics-890dfabb6198

Try it out:

```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/common_deploy
chmod 700 deploy.sh
./deploy.sh
```

# Deploy an S3 Website, TLS Certificate, and CloudFront distribution

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

# Deploy DNS records:

NOT FINISHED

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

# Deploy IAM user with password in secret 
The secret can only be accessed by the IAM user and the person running the script.

The file run.sh runs the scripts and tempaltes documented in these posts:

```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/iam-user
chmod 700 run.sh
./run.sh
```

# Deploy shared network

The file run.sh runs the scripts and tempaltes documented in these posts:

NOT FINISHED

```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/network
chmod 700 run.sh
./run.sh
```

# Get the latest official AMI ID for any operating system: 

https://medium.com/cloud-security/using-q-developer-to-create-a-script-to-get-the-latest-ami-id-e47c413ab8bf

```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/ec2/scripts
chmod 700 get-latest-ami.sh
./get-latest-ami.sh
```

# Launch an EC2 instance. Optionally create an AMI

NOT FINISHED

1. Get AMI ID
https://medium.com/cloud-security/using-q-developer-to-create-a-script-to-get-the-latest-ami-id-e47c413ab8bf

2. Get EC2 instance type based on criteria: minimum vpcu, minimum memory, max cost
https://medium.com/cloud-security/a-script-to-query-for-ec2-instance-type-by-memory-vcpus-and-cost-c0b82999ffa7


```
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/ec2
chmod 700 run.sh
chmod 700 scripts/get-ec2-instance-type.sh
chmod 700 scripts/get-latest-ami.sh
./run.sh
```
