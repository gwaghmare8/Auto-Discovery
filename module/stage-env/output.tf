output "stage_sg" {
  value       = aws_security_group.stage-security-group.id
  description = "Security group ID for the stage environment"
}