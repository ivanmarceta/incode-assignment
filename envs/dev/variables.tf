variable "project" {
  description = "Short project identifier used in names and tags."
  type        = string
  default     = "incode-sre"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or person responsible for this environment."
  type        = string
  default     = "candidate"
}

variable "repository" {
  description = "Repository URL or name for traceability tags."
  type        = string
  default     = "https://github.com/example/incode-assignment"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones used by the VPC."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per availability zone."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for EKS worker nodes."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Private subnet CIDRs reserved for RDS."
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "eks_cluster_version" {
  description = "Desired Kubernetes version for EKS."
  type        = string
  default     = "1.30"
}

variable "application_namespace" {
  description = "Kubernetes namespace for the demo application."
  type        = string
  default     = "demo"
}

variable "node_group_min_size" {
  description = "Minimum EKS managed node group size."
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum EKS managed node group size."
  type        = number
  default     = 2
}

variable "node_group_desired_size" {
  description = "Desired EKS managed node group size."
  type        = number
  default     = 1
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "demoapp"
}

variable "database_username" {
  description = "Master username for the database."
  type        = string
  default     = "appuser"
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "Database engine version."
  type        = string
  default     = "16.3"
}

variable "rds_multi_az" {
  description = "Whether the database should be multi-AZ."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Protect the database from accidental deletion."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy for lower cost in dev."
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number
  default     = 1
}

variable "extra_tags" {
  description = "Additional tags merged into the standard tagging set."
  type        = map(string)
  default     = {}
}
