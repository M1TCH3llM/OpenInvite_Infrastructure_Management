terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# These providers connect to the EKS cluster once it's created
# so Terraform can also manage Kubernetes resources
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ============================================================
# VPC — Separate from your existing EC2 VPC
# ============================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-eks-vpc"
  cidr = "10.1.0.0/16" # Different CIDR from your existing VPC (10.0.0.0/16)

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Use one NAT gateway to save costs
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS to discover subnets
  tags = {
    "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    Environment                                           = var.environment
    Project                                               = "open-invite"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}

# ============================================================
# EKS Cluster
# ============================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment}-eks-cluster"
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # Public access so you can run kubectl from your machine
  cluster_endpoint_public_access = true

  # Allow your IAM user to manage the cluster
  enable_cluster_creator_admin_permissions = true

  # --------------------------------------------------------
  # Node Groups
  # --------------------------------------------------------
  eks_managed_node_groups = {
    # General purpose nodes for both frontend and backend
    app_nodes = {
      min_size     = 1
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"

      labels = {
        role        = "application"
        Environment = var.environment
      }

      tags = {
        Environment = var.environment
        Project     = "open-invite"
      }
    }
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "open-invite"
  }
}

# ============================================================
# AWS Load Balancer Controller (creates ALBs from K8s Ingress)
# ============================================================

# IAM role that lets the LB controller manage AWS resources
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-lb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Install the LB controller via Helm
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_controller_irsa.iam_role_arn
  }

  depends_on = [module.eks]
}

# ============================================================
# Kubernetes Namespaces
# ============================================================
# Namespaces keep your frontend and backend isolated.
# Think of them like separate "rooms" in your cluster.
# Each can have its own resource limits, network policies,
# and access controls.

resource "kubernetes_namespace" "frontend" {
  metadata {
    name = "frontend"

    labels = {
      app         = "open-invite"
      component   = "frontend"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "backend" {
  metadata {
    name = "backend"

    labels = {
      app         = "open-invite"
      component   = "backend"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

# ============================================================
# ECR Repositories (for your Docker images)
# ============================================================
# Instead of building Docker images on EC2 and running them
# there, with EKS you push images to ECR (like Docker Hub
# but private and inside AWS), and K8s pulls from there.

resource "aws_ecr_repository" "frontend" {
  name                 = "open-invite/frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "open-invite"
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "open-invite/backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "open-invite"
  }
}
