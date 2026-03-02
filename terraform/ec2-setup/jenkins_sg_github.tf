# Allow GitHub webhooks to reach Jenkins
resource "aws_security_group_rule" "jenkins_github_webhooks" {
  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = [
    "0.0.0.0/0"  # Open to all for testing
  ]
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Allow GitHub webhooks and public access"
}
