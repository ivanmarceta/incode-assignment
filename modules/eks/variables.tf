variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier used by the cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnet identifiers for worker nodes."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets are required for EKS."
  }
}

variable "public_subnet_ids" {
  description = "Subnet identifiers for public load balancers."
  type        = list(string)
}

variable "kubernetes_namespace" {
  description = "Application namespace that will later be created in-cluster."
  type        = string
}

variable "node_group_min_size" {
  description = "Minimum node count."
  type        = number

  validation {
    condition     = var.node_group_min_size >= 1
    error_message = "The managed node group must have at least one node."
  }
}

variable "node_group_max_size" {
  description = "Maximum node count."
  type        = number
}

variable "node_group_desired_size" {
  description = "Desired node count."
  type        = number
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes."
  type        = list(string)

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one instance type is required for the managed node group."
  }
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API endpoint should be publicly reachable."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR ranges allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
