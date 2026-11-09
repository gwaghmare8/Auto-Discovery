#!/bin/bash
set -e

# -------------------------------
# 1️⃣ Update system & install dependencies
# -------------------------------
# Add swap first so package installs cannot be OOM-killed on small instances
if ! swapon --show | grep -q swapfile; then
  sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
fi
# A full "yum update" is not needed (and was OOM-killed on t2.micro); install only what we need
sudo yum install -y wget unzip curl git

# -------------------------------
# 2️⃣ Install AWS CLI v2
# -------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ln -svf /usr/local/bin/aws /usr/bin/aws
rm -rf awscliv2.zip aws/

# -------------------------------
# 3️⃣ Install Ansible
# -------------------------------
sudo dnf install -y ansible-core

# -------------------------------
# 4️⃣ Configure SSH for Ansible
# -------------------------------
sudo mkdir -p /home/ec2-user/.ssh
sudo tee /home/ec2-user/.ssh/id_rsa > /dev/null <<EOF2
${private_key}
EOF2
sudo chmod 400 /home/ec2-user/.ssh/id_rsa
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa

# Disable strict host key checking for ec2-user
sudo tee -a /home/ec2-user/.ssh/config > /dev/null <<EOF2
Host *
  StrictHostKeyChecking no
EOF2
sudo chmod 600 /home/ec2-user/.ssh/config
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/config

# -------------------------------
# 5️⃣ Pull Ansible scripts from S3
# -------------------------------
sudo mkdir -p /home/ec2-user/ansible
sudo aws s3 cp s3://${artifacts_bucket}/ansible-script/prod-script.sh /home/ec2-user/ansible/prod-script.sh
sudo aws s3 cp s3://${artifacts_bucket}/ansible-script/stage-script.sh /home/ec2-user/ansible/stage-script.sh
sudo aws s3 cp s3://${artifacts_bucket}/ansible-script/deployment.yaml /home/ec2-user/ansible/deployment.yaml

# Set permissions
sudo chmod 755 /home/ec2-user/ansible/*.sh
sudo chown -R ec2-user:ec2-user /home/ec2-user/ansible

# -------------------------------
# 6️⃣ Create Ansible variable file
# -------------------------------
sudo tee /home/ec2-user/ansible/ansible_vars_file.yml > /dev/null <<EOF2
NEXUS_IP: ${nexus_ip}:8085
NEXUS_PASSWORD_PARAM: ${nexus_password_param}
AWS_REGION: ${region}
EOF2
sudo chown ec2-user:ec2-user /home/ec2-user/ansible/ansible_vars_file.yml
sudo chmod 644 /home/ec2-user/ansible/ansible_vars_file.yml

# -------------------------------
# 7️⃣ Configure cron jobs for scripts
# -------------------------------
sudo crontab -u ec2-user -l > /tmp/mycron || true
echo "* * * * * sh /home/ec2-user/ansible/prod-script.sh" >> /tmp/mycron
echo "* * * * * sh /home/ec2-user/ansible/stage-script.sh" >> /tmp/mycron
sudo crontab -u ec2-user /tmp/mycron
rm -f /tmp/mycron

# -------------------------------
# 8️⃣ Install New Relic
# -------------------------------
NR_KEY=$(aws ssm get-parameter --name "${nr_key_param}" --with-decryption --query Parameter.Value --output text --region ${region})
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="$NR_KEY" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

# -------------------------------
# 9️⃣ Set hostname
# -------------------------------
sudo hostnamectl set-hostname ansible-server

