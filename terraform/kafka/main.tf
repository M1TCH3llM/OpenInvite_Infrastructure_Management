
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


variable "aws_region" {
  default = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP for SSH access (e.g., 76.245.196.39/32)"
  type        = string
}

variable "key_name" {
  description = "Name of your existing AWS key pair"
  type        = string
}

variable "vpc_id" {
  description = "Your existing EC2 VPC ID"
  type        = string
}

variable "subnet_id_az1" {
  description = "Public subnet ID in AZ1 (for kafka-1)"
  type        = string
}

variable "subnet_id_az2" {
  description = "Public subnet ID in AZ2 (for kafka-2)"
  type        = string
}

# ============================================================
# Security Group — Kafka Cluster
# ============================================================
resource "aws_security_group" "kafka" {
  name        = "open-invite-kafka-sg"
  description = "Security group for Kafka cluster"
  vpc_id      = var.vpc_id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access"
  }

  # Kafka broker (client connections)
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Kafka broker - internal VPC"
  }

  # Kafka broker (external client connections)
  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "Kafka broker - external"
  }

  # KRaft controller communication (inter-broker)
  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "KRaft controller"
  }

  # All traffic between Kafka nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Inter-node communication"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "open-invite-kafka-sg"
    Project = "open-invite"
  }
}

# ============================================================
# EC2 Instances — Kafka Nodes
# ============================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "kafka_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  subnet_id              = var.subnet_id_az1
  vpc_security_group_ids = [aws_security_group.kafka.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name    = "open-invite-kafka-1"
    Project = "open-invite"
    Role    = "kafka"
  }
}

resource "aws_instance" "kafka_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  subnet_id              = var.subnet_id_az2
  vpc_security_group_ids = [aws_security_group.kafka.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name    = "open-invite-kafka-2"
    Project = "open-invite"
    Role    = "kafka"
  }
}

# ============================================================
# Outputs
# ============================================================
output "kafka_1_public_ip" {
  value = aws_instance.kafka_1.public_ip
}

output "kafka_1_private_ip" {
  value = aws_instance.kafka_1.private_ip
}

output "kafka_2_public_ip" {
  value = aws_instance.kafka_2.public_ip
}

output "kafka_2_private_ip" {
  value = aws_instance.kafka_2.private_ip
}

output "kafka_security_group_id" {
  value = aws_security_group.kafka.id
}

output "ssh_kafka_1" {
  value = "ssh -i ~/.ssh/open-invite-key ubuntu@${aws_instance.kafka_1.public_ip}"
}

output "ssh_kafka_2" {
  value = "ssh -i ~/.ssh/open-invite-key ubuntu@${aws_instance.kafka_2.public_ip}"
}

output "next_steps" {
  value = <<-EOT

  ============================================
  Kafka EC2 instances created!
  
  Next: Run the Ansible playbook to install Kafka:
  
  ansible-playbook -i inventory.ini \
    --private-key ~/.ssh/open-invite-key \
    setup-kafka.yml \
    -e "kafka1_private_ip=${aws_instance.kafka_1.private_ip}" \
    -e "kafka2_private_ip=${aws_instance.kafka_2.private_ip}" \
    -e "kafka1_public_ip=${aws_instance.kafka_1.public_ip}" \
    -e "kafka2_public_ip=${aws_instance.kafka_2.public_ip}"
  ============================================
  EOT
}
