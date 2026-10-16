# Creating a Bastion host to access the private subnet resources.
resource "aws_security_group" "bastion-security-group" {
  name        = "${var.name}-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-bastion-sg"
  }
}

# Creating IAM role for Bastion host to assume SSM role
resource "aws_iam_role" "bastion-ssm-role" {
  name = "${var.name}-ssm-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the SSM policy to the role
resource "aws_iam_role_policy_attachment" "bastion-ssm-policy" {
  role       = aws_iam_role.bastion-ssm-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create IAM instance profile
resource "aws_iam_instance_profile" "bastion-ssm-profile" {
  name = "${var.name}-bastion-ssm-profile"
  role = aws_iam_role.bastion-ssm-role.name
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create Launch Template for Bastion Host
resource "aws_launch_template" "bastion-launchtemplate" {
  name_prefix   = "${var.name}-bastion-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.keypair
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion-ssm-profile.name
  }
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.bastion-security-group.id]
  }
  user_data = base64encode(templatefile("./module/bastion/bastion-user-data.sh", {
    privatekey   = var.privatekey,
    nr_key_param = var.nr_key_param,
    nr_acc_id    = var.nr_acc_id
    region       = var.region
  }))
  tags = {
    Name = "${var.name}-bastion"
  }
}

resource "aws_autoscaling_group" "bastion-asg" {
  name                      = "${var.name}-bastion-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.bastion-launchtemplate.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.subnets

  tag {
    key                 = "Name"
    value               = "${var.name}-bastion-asg"
    propagate_at_launch = true
  }
}

# Created ASG policy for Baston Host
resource "aws_autoscaling_policy" "bastion-asg-policy" {
  name                   = "${var.name}-bastion-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.bastion-asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
# Allow reading the New Relic API key from SSM Parameter Store
resource "aws_iam_role_policy" "newrelic_key_read" {
  name = "${var.name}-newrelic-key-read"
  role = aws_iam_role.bastion-ssm-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:*:*:parameter${var.nr_key_param}"
    }]
  })
}
