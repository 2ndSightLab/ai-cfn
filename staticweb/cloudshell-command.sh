# run these commands in the AWS account 
# where you want to deploy the website
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 deploy.sh
chmod 700 scripts/deploy/route53-tls-cert-validation.sh
./deploy.sh

# run these commands to update the 
# name servers where the primary domain exists
# for a non-production domain only 
# entering the name servers output by the above script
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 update-nameservers.sh
./update-nameservers.sh
