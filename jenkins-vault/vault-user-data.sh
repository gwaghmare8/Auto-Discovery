#!/bin/bash
set -e
apt install -y unzip jq
# Define Vault version
VAULT_VERSION="1.18.3"
# Download Vault binary
wget https://releases.hashicorp.com/vault/"${VAULT_VERSION}"/vault_"${VAULT_VERSION}"_linux_amd64.zip
# Unzip the Vault binary
unzip vault_"${VAULT_VERSION}"_linux_amd64.zip
# Move the binary to /usr/local/bin
sudo mv vault /usr/local/bin/
# Set ownership and permissions
sudo chown root:root /usr/local/bin/vault
sudo chmod 0755 /usr/local/bin/vault
# Create Vault user and directories
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo mkdir --parents /etc/vault.d
sudo mkdir --parents /var/lib/vault
sudo chown --recursive vault:vault /etc/vault.d /var/lib/vault
# Create Vault configuration file
cat <<EOF | sudo tee /etc/vault.d/vault.hcl
storage "file" {
    path = "/var/lib/vault"
}
listener "tcp" {
    address     = "0.0.0.0:8200"
    tls_disable = 1
}
seal "awskms" {
    region = "${region}"
    kms_key_id = "${key}"
}
ui = true
EOF
# Set permissions for the configuration file
sudo chown vault:vault /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl
# Create systemd service file for Vault
cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
[Install]
WantedBy=multi-user.target
EOF
# Reload systemd to recognize the new service
sudo systemctl daemon-reload
# Wait for Vault to start
sleep 5
# create a variable for the vault URL
export VAULT_ADDR='http://localhost:8200'
cat <<EOT > /etc/profile.d/vault.sh
export VAULT_ADDR='http://localhost:8200'
export VAULT_SKIP_VERIFY=true
EOT
# Enable and start the Vault service
sudo systemctl enable vault
sudo systemctl start vault
sleep 20
# Initialize the vault server (output is kept in memory only, never written to disk)
INIT_OUTPUT=$(vault operator init -format=json)
export VAULT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r .root_token)

# Install AWS CLI v2 so the init output (root token + recovery keys) can be stored in Secrets Manager
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
/usr/local/bin/aws secretsmanager create-secret --name "${init_secret_name}" \
  --description "Vault init output: root token and recovery keys" \
  --secret-string "$INIT_OUTPUT" --region ${region} \
  || /usr/local/bin/aws secretsmanager put-secret-value --secret-id "${init_secret_name}" \
  --secret-string "$INIT_OUTPUT" --region ${region}
unset INIT_OUTPUT

# create secret engine and store secrets for the application database
vault secrets enable -path=secret/ kv #directory to store secrets on the vault server
# the DB password is generated here and only ever stored in Vault (Terraform reads it for RDS)
DB_PASSWORD=$(openssl rand -hex 16)
vault kv put secret/database username=petclinic password="$DB_PASSWORD"
unset DB_PASSWORD

# Let the Jenkins EC2 role log in with AWS auth (no stored token needed by Terraform)
vault policy write terraform - <<POLICY
path "secret/database" {
  capabilities = ["read"]
}
path "auth/token/create" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
POLICY
vault auth enable aws
vault write auth/aws/role/jenkins-terraform auth_type=iam \
  bound_iam_principal_arn="${jenkins_role_arn}" policies=terraform ttl=1h

# Revoke the root token: nothing on this server holds it any more
vault token revoke -self
unset VAULT_TOKEN

# Set hostname to Vault
sudo hostnamectl set-hostname Vault
