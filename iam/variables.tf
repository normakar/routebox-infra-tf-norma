variable "environment" {
  description = "Which environment this module instance is for. Drives role names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "cost_center" {
  description = "Cost-allocation tag value."
  type        = string
  default     = "platform"
}
