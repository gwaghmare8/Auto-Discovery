locals {
  name = "vault-jenkins"
}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    tags = {
        Name = "${local.name}-vpc"
    }
}

# creating public subnets
resource "aws_subnet" "pub_sub" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-1a"

    tags = {
        Name = "${local.name}-pub-subnet"
    }
}

#creating internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "${local.name}-igw"
    }
}

# creating route table
resource "aws_route_table" "public-rt" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "${local.name}-public-rt"
    }
}


# creating route table association
resource "aws_route_table_association" "public-rt-association" {
    subnet_id = aws_subnet.pub_sub.id
    route_table_id = aws_route_table.public-rt.id
}

# creating keypair resource
resource "tls_private_key" "keypair" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "local_file" "private-key" {
    content  = tls_private_key.keypair.private_key_pem
    filename = "${local.name}-key.pem"
    file_permission = "400"
}

resource "aws_key_pair" "public-key" {
    key_name   = "${local.name}-key"
    public_key = tls_private_key.keypair.public_key_openssh
}

# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
    most_recent = true
    owners      = ["309956199498"] # RedHat owner ID

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


resource "aws_instance" "jenkins-server" {
  ami                         = data.aws_ami.redhat.id # redhat in eu-west-1
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.public_key.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_security_group.id]
#   iam_instance_profile        = aws_iam_instance_profile.jenkins_ssm_instance_profile.name
  subnet_id = aws_subnet.pub_sub.id
  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # General Purpose SSD (recommended)
    encrypted   = true  # Enable encryption (best practice)
  }
user_data = templatefile("./jenkins-user-data.sh", {
 
    region    = var.region
  })
  metadata_options {
    http_tokens = "required"
 
  }
 
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# # Attach  AmazonSSMManaged policy to JENKIN IAM role
# resource "aws_iam_role_policy_attachment" "jenkins_ssm_managed_instance_core" {
#   role       = aws_iam_role.jenkins-ssm-jenkins-role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }
# # Attach ADMINISTRATOR ACCESS policy to the role
# resource "aws_iam_role_policy_attachment" "jenkins-admin-role-attachment" {
#   role       = aws_iam_role.jenkins-ssm-jenkins-role.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
# # CREATE INSTANCE PROFILE FOR JENKINS SERVER
# resource "aws_iam_instance_profile" "jenkins_ssm_instance_profile" {
#   name = "${local.name}-ssm-jenkins-profile"
#   role = aws_iam_role.jenkins-ssm-jenkins-role.name
# }
 
# Create jenkins security group
resource "aws_security_group" "jenkins_security_group" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow SSH and HTTPS"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}