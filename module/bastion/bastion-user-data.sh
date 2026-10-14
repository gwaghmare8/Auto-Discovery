#!/bin/bash
# Setup SSH Key
mkdir -p /home/ubuntu/.ssh
echo "${privatekey}" > /home/ubuntu/.ssh/id_rsa
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# Set hostname
hostnamectl set-hostname bastion

# Install New Relic
# Install AWS CLI v2 (needed to read the New Relic key from SSM)
apt-get install -y unzip
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
NR_KEY=$(/usr/local/bin/aws ssm get-parameter --name "${nr_key_param}" --with-decryption --query Parameter.Value --output text --region ${region})
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
sudo NEW_RELIC_API_KEY="$NR_KEY" \
     NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
     NEW_RELIC_REGION=EU \
     /usr/local/bin/newrelic install -y
