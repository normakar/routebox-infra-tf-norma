variable "environment" {
  description = "Which environment this module instance is for. Drives resource names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "private_subnet_ids" {
  description = "Three private subnet IDs for the DB subnet group, ordered [a, b, c]. Pass module.network.private_subnet_ids."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) == 3
    error_message = "private_subnet_ids must have exactly 3 entries."
  }
}

variable "rds_security_group_id" {
  description = "ID of the RDS security group created by the network module."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class. db.t3.small for dev, db.t3.medium for staging, db.m5.xlarge for prod."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB. 20 for dev, 100 for staging, 500 for prod."
  type        = number
  default     = 100

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 1000
    error_message = "db_allocated_storage must be between 20 and 1000 GiB."
  }
}

variable "db_engine_version" {
  description = "Postgres engine version. Pinned at 14.10 — don't bump without coordinating with ops-console (Rails 6 + strong_migrations constraint)."
  type        = string
  default     = "14.10"
}

variable "db_master_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "routebox_admin"
}

variable "db_master_password" {
  description = "Master password. Passed in via tfvars or TF_VAR_rds_master_password. Marked sensitive so it does not appear in plan output or state diffs."
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ standby. false for dev/staging, true for prod."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention in days. 1 for dev, 7 for staging, 30 for prod."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent the instance from being deleted via the API. Always true for prod."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights. Always true for prod."
  type        = bool
  default     = false
}

variable "performance_insights_retention_days" {
  description = "Retention period for Performance Insights data in days. Only used when performance_insights_enabled = true."
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. 0 disables it; 60 for prod. When > 0 the module looks up the routebox-<env>-rds-monitoring IAM role by name."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "skip_final_snapshot" {
  description = "Skip the final DB snapshot on deletion. true for dev (cost), false for staging/prod to mirror CFN DeletionPolicy: Snapshot."
  type        = bool
  default     = false
}

variable "max_connections" {
  description = "Override max_connections in the parameter group. null = use the RDS engine default. Set to 400 for prod (matches the hand-edit applied to the CFN parameter group that was never committed back to the template)."
  type        = number
  default     = null
}

variable "cost_center" {
  description = "Cost-allocation tag value. Inherited from the environment's provider default_tags; also set explicitly on the subnet group which doesn't pick up default_tags in older provider versions."
  type        = string
  default     = "platform"
}
