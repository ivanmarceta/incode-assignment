output "vpc_id" {
  description = "VPC identifier."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = module.network.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS control plane endpoint."
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS connection endpoint."
  value       = module.rds.db_endpoint
}

output "rds_security_group_id" {
  description = "Security group protecting the RDS instance."
  value       = module.rds.security_group_id
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed RDS master credential."
  value       = module.rds.master_user_secret_arn
}
