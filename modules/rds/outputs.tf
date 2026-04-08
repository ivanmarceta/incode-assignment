output "db_endpoint" {
  description = "Database endpoint hostname."
  value       = aws_db_instance.database.address
}

output "db_port" {
  description = "Database listener port."
  value       = aws_db_instance.database.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.database.db_name
}

output "security_group_id" {
  description = "Security group identifier."
  value       = aws_security_group.database.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for the managed master password, if enabled."
  value       = try(aws_db_instance.database.master_user_secret[0].secret_arn, null)
}
