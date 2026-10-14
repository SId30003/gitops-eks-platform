terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Replace the bucket name after you run the bootstrap step
  backend "s3" {
    bucket         = "sid-tfstate-730335321410"
    key            = "dev/platform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "gitops-eks-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  cluster_name = "gitops-${var.environment}"
}

module "vpc" {
  source       = "../../modules/vpc"
  name         = "gitops-${var.environment}"
  azs          = ["${var.region}a", "${var.region}b"]
  cluster_name = local.cluster_name
}

module "eks" {
  source        = "../../modules/eks"
  cluster_name  = local.cluster_name
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnet_ids
  capacity_type = "SPOT" # dev only: cheaper, can be interrupted
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "gitops-demo-app"
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
