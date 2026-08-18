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