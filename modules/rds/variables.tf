variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier hosting the database."
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet identifiers used by the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "At least two database subnets are required for RDS."
  }
}

variable "app_security_group_id" {
  description = "Security group that should be allowed to reach the database."
  type        = string
}

variable "database_name" {
  description = "Initial application database name."
  type        = string
}

variable "database_username" {
  description = "Master username."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GiB."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "engine" {
  description = "Database engine."
  type        = string
  default     = "postgres"
}

variable "port" {
  description = "Database listener port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Whether to provision a standby in another AZ."
  type        = bool
}

variable "deletion_protection" {
  description = "Prevents accidental deletion."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot during destroy."
  type        = bool
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number

  validation {
    condition     = var.backup_retention_period >= 0
    error_message = "Backup retention must be zero or greater."
  }
}

variable "storage_encrypted" {
  description = "Whether storage should be encrypted at rest."
  type        = bool
  default     = true
}

variable "manage_master_user_password" {
  description = "Store and rotate the master password in AWS Secrets Manager."
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Whether to enable RDS Performance Insights."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the database should be publicly accessible."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
