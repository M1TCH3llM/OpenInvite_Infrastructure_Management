# Allow Jenkins to access frontend server
resource "aws_security_group_rule" "jenkins_to_frontend" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_sg.id
  security_group_id        = aws_security_group.frontend.id
  description              = "Allow SSH from Jenkins"
}
