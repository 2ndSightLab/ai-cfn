#use these commands to run the scripts in the AWS account where the website exists
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 deploy.sh
chmod 700 scripts/deploy/tls-cert-validation.sh
./deploy.sh

#use these commands to run the script to update the name servers where the primary domain exists
cd ~
rm -rf ai-cfn
git clone https://github.com/2ndSightLab/ai-cfn.git
cd ai-cfn/staticweb
chmod 700 update-nameservers.sh
./update-nameservers.sh
