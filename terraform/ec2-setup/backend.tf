# Backend EC2 Instances (2 for load balancing)
resource "aws_instance" "backend" {
  count         = 2  # Create 2 instances
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  
  tags = {
    Name = "${var.project_name}-${var.environment}-backend-${count.index + 1}"
  }
}

# Security Group for Backend
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-${var.environment}-backend-sg"
  description = "Security group for backend servers"
  vpc_id      = aws_vpc.main.id
  
  # HTTP from ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }
  
  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access"
  }
  
  # SSH from Jenkins
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
    description     = "SSH from Jenkins"
  }
  
  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-backend-sg"
  }
}

# Outputs
output "backend_public_ips" {
  value       = aws_instance.backend[*].public_ip
  description = "Public IPs of backend instances"
}

output "backend_private_ips" {
  value       = aws_instance.backend[*].private_ip
  description = "Private IPs of backend instances"
}
