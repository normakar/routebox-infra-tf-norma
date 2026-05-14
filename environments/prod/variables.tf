variable "environment" {
  description = "Which environment this stack instance is for. Drives tags and resource names."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region. Defaults to us-east-1 to match deploy.sh."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 in practice."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Three public subnet CIDRs, ordered [a, b, c]."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Three private subnet CIDRs, ordered [a, b, c]."
  type        = list(string)
}

variable "cost_center" {
  description = "Cost-allocation tag value applied via provider default_tags and re-used inside the network module."
  type        = string
  default     = "platform"
}

variable "enable_nat_gateway" {
  description = "Toggle the network module's NAT gateway on or off. Default off — private subnets have no internet egress when off."
  type        = bool
}

# ------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
}

variable "rds_engine_version" {
  description = "Postgres engine version."
  type        = string
}

variable "rds_master_username" {
  description = "RDS master username."
  type        = string
}

variable "rds_master_password" {
  description = "RDS master password. Use TF_VAR_rds_master_password env var rather than committing the value."
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ standby."
  type        = bool
}

variable "rds_backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
}

variable "rds_deletion_protection" {
  description = "Prevent the instance from being deleted via the API."
  type        = bool
}

variable "rds_performance_insights_enabled" {
  description = "Enable RDS Performance Insights."
  type        = bool
}

variable "rds_performance_insights_retention_days" {
  description = "Performance Insights data retention in days."
  type        = number
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. 0 = disabled."
  type        = number
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final snapshot on instance deletion."
  type        = bool
}

variable "rds_max_connections" {
  description = "Override max_connections in the parameter group. null = use RDS engine default."
  type        = number
  default     = null
}

# ------------------------------------------------------------------
# EKS — surface mirrors the eks module's variables. Values come
# from <env>.tfvars; no defaults at this layer.
# ------------------------------------------------------------------

variable "eks_kubernetes_version" {
  description = "Kubernetes minor version pinned on the EKS cluster."
  type        = string
}

variable "eks_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the API server. Public + IAM-gated."
  type        = list(string)
}

variable "eks_node_instance_types" {
  description = "Allowed node instance types for the managed node group."
  type        = list(string)
}

variable "eks_node_capacity_type" {
  description = "Node capacity type: SPOT or ON_DEMAND."
  type        = string
}

variable "eks_node_disk_size_gb" {
  description = "Root EBS volume size per node, GiB."
  type        = number
}

variable "eks_node_min_size" {
  description = "Minimum node count."
  type        = number
}

variable "eks_node_desired_size" {
  description = "Desired node count at apply time. Subsequent changes are ignored so the cluster autoscaler can drift it."
  type        = number
}

variable "eks_node_max_size" {
  description = "Maximum node count."
  type        = number
}

variable "eks_cluster_admin_role_arns" {
  description = "IAM role ARNs to grant cluster-admin via EKS access entries (AmazonEKSClusterAdminPolicy, scope = cluster). Typically the SSO admin role for this account."
  type        = list(string)
}
