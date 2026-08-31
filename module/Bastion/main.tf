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