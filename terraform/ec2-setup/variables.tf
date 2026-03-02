# AWS Region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Project Name
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "open-invite"
}

# Environment
variable "environment" {
  description = "Environment (staging/qa/prod)"
  type        = string
  default     = "staging"
}

# EC2 Instance Type
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "openinvite"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# SSH Key Name
variable "key_name" {
  description = "AWS EC2 key pair name"
  type        = string
  default     = "open-invite-key"
}

# Your IP for SSH access
variable "my_ip" {
  description = "Your IP address for SSH access (CIDR format)"
  type        = string
}
