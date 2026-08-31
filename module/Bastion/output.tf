output "bastion_sg" {
  value = aws_security_group.bastion-security-group.id
}