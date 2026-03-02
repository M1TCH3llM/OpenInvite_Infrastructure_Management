# ============================================================
# Variables
# ============================================================

variable "environment" {
  description = "Environment name (used in resource naming)"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region — matches your existing EC2 setup"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}
