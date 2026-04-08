output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA data."
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group protecting the EKS control plane."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group used by worker nodes."
  value       = aws_security_group.node.id
}

output "node_role_arn" {
  description = "IAM role ARN attached to the managed node group."
  value       = aws_iam_role.node.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the EKS cluster."
  value       = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
