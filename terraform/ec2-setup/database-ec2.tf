# EC2 PostgreSQL Database
resource "aws_instance" "database" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.database_ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-database"
  }
}

# Security Group for Database EC2
resource "aws_security_group" "database_ec2_sg" {
  name        = "${var.project_name}-${var.environment}-database-ec2-sg"
  description = "Security group for PostgreSQL EC2"
  vpc_id      = aws_vpc.main.id
  
  # PostgreSQL from backend
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "PostgreSQL from backend"
  }
  
  # PostgreSQL from Jenkins (for migrations)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
    description     = "PostgreSQL from Jenkins"
  }
  
  # SSH from your IP
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
    Name = "${var.project_name}-${var.environment}-database-ec2-sg"
  }
}

# Output Database IP
output "database_ec2_public_ip" {
  value       = aws_instance.database.public_ip
  description = "Public IP of database EC2"
}

output "database_ec2_private_ip" {
  value       = aws_instance.database.private_ip
  description = "Private IP of database EC2"
}
