
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

# ============================================================
# Variables
# ============================================================
variable "aws_region" {
  default = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP for SSH access (e.g., 71.201.5.155/32)"
  type        = string
}

variable "key_name" {
  description = "Name of your existing AWS key pair (e.g., open-invite-key)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to launch into (your existing EC2 VPC)"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID to launch into"
  type        = string
}

# ============================================================
# IAM Role — Allows the EC2 to access ECR and EKS
# ============================================================
resource "aws_iam_role" "deploy_server" {
  name = "open-invite-deploy-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# ECR access — push/pull Docker images
resource "aws_iam_role_policy_attachment" "ecr_full" {
  role       = aws_iam_role.deploy_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# EKS access — manage the cluster
resource "aws_iam_role_policy_attachment" "eks_full" {
  role       = aws_iam_role.deploy_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS worker node access
resource "aws_iam_role_policy_attachment" "eks_worker" {
  role       = aws_iam_role.deploy_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# STS access — needed for kubectl auth
resource "aws_iam_role_policy" "sts_eks" {
  name = "eks-sts-access"
  role = aws_iam_role.deploy_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "deploy_server" {
  name = "open-invite-deploy-server-profile"
  role = aws_iam_role.deploy_server.name
}

# ============================================================
# Security Group
# ============================================================
resource "aws_security_group" "deploy_server" {
  name        = "open-invite-deploy-server-sg"
  description = "Security group for deployment server"
  vpc_id      = var.vpc_id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH access"
  }

  # Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "Jenkins UI"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "open-invite-deploy-server-sg"
  }
}

# ============================================================
# EC2 Instance
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

resource "aws_instance" "deploy_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.deploy_server.id]
  iam_instance_profile   = aws_iam_instance_profile.deploy_server.name

  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name    = "open-invite-deploy-server"
    Project = "open-invite"
  }
}

# ============================================================
# Outputs
# ============================================================
output "deploy_server_public_ip" {
  value = aws_instance.deploy_server.public_ip
}

output "deploy_server_private_ip" {
  value = aws_instance.deploy_server.private_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.deploy_server.public_ip}:8080"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/open-invite-key ubuntu@${aws_instance.deploy_server.public_ip}"
}
