# Jenkins Server
resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins"
  }
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-${var.environment}-jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.main.id
  
  # Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "Jenkins web UI"
  }
  
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access"
  }
  
  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  }
}

# Output Jenkins IP
output "jenkins_public_ip" {
  value       = aws_instance.jenkins.public_ip
  description = "Public IP of Jenkins server"
}
