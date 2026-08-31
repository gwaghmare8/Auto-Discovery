# Create AWS KMS
resource "aws_kms_key" "kms-vault" {
  description             = "save vault unseal key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
}
 
# create policy for kms key
data "aws_iam_policy_document" "policy-doc" {
  statement {
    effect    = "Allow"
    sid       = "VaultUnsealKey"
    resources = [aws_kms_key.kms-vault.arn]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
  }
}
 
resource "aws_iam_policy" "kms-policy" {
  name        = "kms-policy-doc1"
  description = "the policy for vault unseal key"
  policy      = data.aws_iam_policy_document.policy-doc.json
}
 
# create assume for ec2
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
 
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
 
    actions = ["sts:AssumeRole"]
  }
}
 
resource "aws_iam_role" "IAM-KMS" {
  name               = "IAM-KMS"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
 
resource "aws_iam_role_policy_attachment" "kms-policy-attach" {
  role       = aws_iam_role.IAM-KMS.name
  policy_arn = aws_iam_policy.kms-policy.arn
}
 
resource "aws_iam_role_policy_attachment" "ssm-policy-attach" {
  role       = aws_iam_role.IAM-KMS.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
 
resource "aws_iam_instance_profile" "kms-instance-profile" {
  name = "kms-ssm-instance-profile"
  role = aws_iam_role.IAM-KMS.name
}
 