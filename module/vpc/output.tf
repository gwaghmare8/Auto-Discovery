output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "public_subnet_id" {
    value = aws_subnet.public_sub1.id
}

output "public_subnet2_id" {
    value = aws_subnet.public_sub2.id
}

output "private_subnet_id" {
    value = aws_subnet.private_sub1.id
}

output "private_subnet2_id" {
    value = aws_subnet.private_sub2.id
}