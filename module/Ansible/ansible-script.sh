locals {
  ansible_userdata = <<-EOF
#!/bin/bash
set -e

# -------------------------------
# 1️⃣ Update system & install dependencies
# -------------------------------
sudo yum update -y
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
${var.private-key}
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
sudo aws s3 cp s3://pet-adoption-state-bucket-one-team-1/ansible-script/prod-bashscript.sh /home/ec2-user/ansible/prod-bashscript.sh
sudo aws s3 cp s3://pet-adoption-state-bucket-one-team-1/ansible-script/stage-bashscript.sh /home/ec2-user/ansible/stage-bashscript.sh
sudo aws s3 cp s3://pet-adoption-state-bucket-one-team-1/ansible-script/deployment.yml /home/ec2-user/ansible/deployment.yml

# Set permissions
sudo chmod 755 /home/ec2-user/ansible/*.sh
sudo chown -R ec2-user:ec2-user /home/ec2-user/ansible

# -------------------------------
# 6️⃣ Create Ansible variable file
# -------------------------------
sudo tee /home/ec2-user/ansible/ansible_vars_file.yml > /dev/null <<EOF2
NEXUS_IP: ${var.nexus-ip}:8085
EOF2
sudo chown ec2-user:ec2-user /home/ec2-user/ansible/ansible_vars_file.yml
sudo chmod 644 /home/ec2-user/ansible/ansible_vars_file.yml

# -------------------------------
# 7️⃣ Configure cron jobs for scripts
# -------------------------------
sudo crontab -u ec2-user -l > /tmp/mycron || true
echo "* * * * * sh /home/ec2-user/ansible/prod-bashscript.sh" >> /tmp/mycron
echo "* * * * * sh /home/ec2-user/ansible/stage-bashscript.sh" >> /tmp/mycron
sudo crontab -u ec2-user /tmp/mycron
rm -f /tmp/mycron

# -------------------------------
# 8️⃣ Install New Relic
# -------------------------------
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="${var.nr_key}" NEW_RELIC_ACCOUNT_ID="${var.nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

# -------------------------------
# 9️⃣ Set hostname
# -------------------------------
sudo hostnamectl set-hostname ansible-server

EOF
}