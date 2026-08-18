# creating the vpc
resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    tags = {
        Name = "${var.name}-vpc"
    }
}

# creating a public subnet 1
resource "aws_subnet" "public_sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    tags = {
        Name = "${var.name}-public-sub1"
    }
}

# creating a public subnet 2
resource "aws_subnet" "public_sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.2.0/24"
    tags = {
        Name = "${var.name}-public-sub2"
    }
}

# creating a private subnet 1
resource "aws_subnet" "private_sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.3.0/24"
    tags = {
        Name = "${var.name}-private-sub1"
    }
}

# creating a private subnet 2
resource "aws_subnet" "private_sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.4.0/24"
    tags = {
        Name = "${var.name}-private-sub2"
    }
}

# creating internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "${var.name}-igw"
    }
}

# creating elastic ip for NAT gateway
resource "aws_eip" "eip" {
    domain = "vpc"
    tags = {
        Name = "${var.name}-eip"
    }
}

# creating NAT gateway
resource "aws_nat_gateway" "ngw" {
    allocation_id = aws_eip.eip.id
    subnet_id = aws_subnet.public_sub1.id
    depends_on = [aws_eip.eip] # ensuring the EIP is created before the NAT gateway
    tags = {
        Name = "${var.name}-ngw"
    }
}

# creating route table for public subnets
resource "aws_route_table" "public_routetable" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.name}-pub_routetable"
    }
}

# creating route table for private subnets
resource "aws_route_table" "private_routetable" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.ngw.id
    }
    tags = {
        Name = "${var.name}-pri_routetable"
    }
}

# creating route table association for public subnet 1
resource "aws_route_table_association" "public_sub1_association" {
    subnet_id = aws_subnet.public_sub1.id
    route_table_id = aws_route_table.public_routetable.id
}

# creating route table association for public subnet 2
resource "aws_route_table_association" "public_sub2_association" {
    subnet_id = aws_subnet.public_sub2.id
    route_table_id = aws_route_table.public_routetable.id
}

# creating route table association for private subnet 1
resource "aws_route_table_association" "private_sub1_association" {
    subnet_id = aws_subnet.private_sub1.id
    route_table_id = aws_route_table.private_routetable.id
}

# creating route table association for private subnet 2
resource "aws_route_table_association" "private_sub2_association" {
    subnet_id = aws_subnet.private_sub2.id
    route_table_id = aws_route_table.private_routetable.id
}

# creating keypair RSA key of size 4096 bits
resource "tls_private_key" "key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# creating private key
resource "local_file" "private-key" {
    content = tls_private_key.key.private_key_pem
    filename = "${var.name}-key.pem"
    file_permission = 440
}

# creating public key
resource "aws_key_pair" "public-key" {
    key_name = "${var.name}-infra-key"
    public_key = tls_private_key.key.public_key_openssh
}