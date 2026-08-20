#!/usr/bin/env bash
set -euo pipefail

BUCKET_NAME="terraform-state-$(aws sts get-caller-identity --query 'Account' --output text)"
REGION="eu-east-1"
DYNAMODB_TABLE="application-state-dynamodb-lock"

echo "Creating S3 backend: application-state-s3-backend"

# Create S3 bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --object-lock-enabled-for-bucket --create-bucket-configuration LocationConstraint="$REGION"
echo "✔ Bucket created"

# Enable versioning on the bucket
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
echo "✔ Versioning enabled"

# Create DynamoDB table for state locking
aws dynamodb create-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --output json > /dev/null
echo "✔ DynamoDB lock table created: $DYNAMODB_TABLE"

echo "Done. Run: terraform init"

echo "Creating Vault and Jenkins Server"
cd jenkins-vault
terraform init 
terraform validate
terraform apply -auto-approve