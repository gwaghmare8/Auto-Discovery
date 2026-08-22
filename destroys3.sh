echo "deleting jenkins and vault server"
cd jenkins-vault
terraform init 
terraform destroy -auto-approve

BUCKET_NAME="auto-discovery-terraform-state"
REGION="eu-west-1"
DYNAMODB_TABLE="auto-discovery-terraform-state-dynamodb-lock"

# Delete all object versions
echo "Deleting all object versions in bucket: $BUCKET_NAME"
VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json)

if [[ "$VERSIONS" != "null" && "$VERSIONS" != "[]" ]]; then
  echo "$VERSIONS" | jq -c '.[]' | while read -r obj; do
    KEY=$(echo "$obj" | jq -r '.Key')
    VID=$(echo "$obj" | jq -r '.VersionId')
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VID" --region "$REGION" > /dev/null
  done
fi
echo "✔ Object versions deleted"


# Delete all delete markers
echo "Deleting all delete markers..."
MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json)

if [[ "$MARKERS" != "null" && "$MARKERS" != "[]" ]]; then
  echo "$MARKERS" | jq -c '.[]' | while read -r obj; do
    KEY=$(echo "$obj" | jq -r '.Key')
    VID=$(echo "$obj" | jq -r '.VersionId')
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VID" --region "$REGION" > /dev/null
  done
fi
echo "✔ Delete markers removed"


# delete dynamodb table
echo "Deleting DynamoDB lock table..."
aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$REGION" > /dev/null
echo "✔ DynamoDB lock table deleted: $DYNAMODB_TABLE"

# delete the bucket
aws s3api delete-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

echo "✔ Bucket deleted: $BUCKET_NAME"