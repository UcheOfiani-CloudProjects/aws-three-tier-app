#!/bin/bash
yum update -y
yum install -y git curl

curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Get app files (assuming hosted on GitHub)
git clone https://github.com/UcheOfiani-CloudProjects/aws-three-tier-app/home/ec2-user/app
cd /home/ec2-user/app

# Set environment variables
echo "export DB_HOST='${rds_endpoint}'" >> /etc/profile
echo "export DB_PASSWORD='${db_password}'" >> /etc/profile
source /etc/profile

npm install
node app.js > app.log 2>&1 &
