# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat's owner ID
  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Creating ansible security group
resource "aws_security_group" "ansible-security-group" {
  name        = "${var.name}-ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc

  ingress {
    description     = "sshport"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_key]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-ansible-sg"
  }
}

# Create Ansible Server
resource "aws_instance" "ansible-server" {
  ami                    = data.aws_ami.redhat.id #rehat 
  instance_type          = "t2.medium"            # t2.micro (1 GB) was OOM-killed during yum update
  iam_instance_profile   = aws_iam_instance_profile.IAM-ansible-profile.name
  vpc_security_group_ids = [aws_security_group.ansible-security-group.id]
  key_name               = var.keypair
  depends_on             = [null_resource.ansible-setup]
  subnet_id              = var.subnet_id
  user_data = templatefile("${path.module}/ansible-script.sh", {
    private_key          = var.private-key,
    nexus_ip             = var.nexus-ip,
    nr_key_param         = var.nr_key_param,
    nexus_password_param = var.nexus_password_param,
    region               = var.region,
    nr_acc_id            = var.nr_acc_id,
    artifacts_bucket     = var.artifacts_bucket
  })
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = "${var.name}-ansible-server"
  }
}


# Create IAM role for ansible
resource "aws_iam_role" "ansible-IAM-role" {
  name = "ansible-discovery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


# Attach the EC2 full access policy to the role
resource "aws_iam_role_policy_attachment" "IAM-ec2-policy" {
  role       = aws_iam_role.ansible-IAM-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Attach S3 full access policy to the role
resource "aws_iam_role_policy_attachment" "IAM-s3-policy" {
  role       = aws_iam_role.ansible-IAM-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# Create IAM instance profile for ansible
resource "aws_iam_instance_profile" "IAM-ansible-profile" {
  name = "ansible-discovery-profile"
  role = aws_iam_role.ansible-IAM-role.name
}
resource "null_resource" "ansible-setup" {
  # re-upload the scripts whenever any of them changes
  triggers = {
    scripts = sha1(join(",", [for f in sort(fileset("${path.module}/scripts", "*")) : filesha1("${path.module}/scripts/${f}")]))
  }

  provisioner "local-exec" {
    command = <<EOT
      aws s3 cp --recursive ${path.module}/scripts/ s3://${var.artifacts_bucket}/ansible-script/ 
    EOT
  }
}

# Allow reading the New Relic API key from SSM Parameter Store
resource "aws_iam_role_policy" "newrelic_key_read" {
  name = "${var.name}-newrelic-key-read"
  role = aws_iam_role.ansible-IAM-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:*:*:parameter${var.nr_key_param}"
    }]
  })
}
