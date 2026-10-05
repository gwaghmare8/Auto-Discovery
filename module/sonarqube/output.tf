output "sonarqube_sg" {
  value       = aws_security_group.sonarqube-sg.id
  description = "Security group ID for the SonarQube server"
}
