terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Repository  = var.repository
    },
    var.extra_tags
  )
}

module "network" {
  source = "../../modules/network"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  tags                  = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name_prefix             = local.name_prefix
  cluster_version         = var.eks_cluster_version
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  public_subnet_ids       = module.network.public_subnet_ids
  kubernetes_namespace    = var.application_namespace
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
  node_instance_types     = var.node_instance_types
  tags                    = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix             = local.name_prefix
  vpc_id                  = module.network.vpc_id
  database_subnet_ids     = module.network.database_subnet_ids
  app_security_group_id   = module.eks.node_security_group_id
  database_name           = var.database_name
  database_username       = var.database_username
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  engine_version          = var.rds_engine_version
  multi_az                = var.rds_multi_az
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
  backup_retention_period = var.rds_backup_retention_period
  tags                    = local.tags
}

module "frontend" {
  source = "../../modules/frontend"

  name_prefix = local.name_prefix
  tags        = local.tags
}
