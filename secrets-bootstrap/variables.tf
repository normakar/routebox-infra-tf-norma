variable "environment" {
  description = "Which environment this module instance is for."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role (from the iam module). Granted kms:Decrypt on the app secrets key."
  type        = string
}

variable "cost_center" {
  description = "Cost-allocation tag value."
  type        = string
  default     = "platform"
}
