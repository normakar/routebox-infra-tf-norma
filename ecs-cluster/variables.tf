variable "environment" {
  description = "Which environment this module instance is for."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  description = "VPC ID from the network module. Used for target group VPC binding."
  type        = string
}

variable "public_subnet_ids" {
  description = "Three public subnet IDs for the ALB. Pass module.network.public_subnet_ids."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) == 3
    error_message = "public_subnet_ids must have exactly 3 entries."
  }
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group from the network module."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener. Provisioned by hand (not in CFN/TF)."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days. 7 for dev, 14 for staging, 90 for prod."
  type        = number
  default     = 30
}

variable "cost_center" {
  description = "Cost-allocation tag value."
  type        = string
  default     = "platform"
}
