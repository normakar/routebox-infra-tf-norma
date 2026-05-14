variable "cost_center" {
  description = "Cost-allocation tag value. ECR repos are global (not per-env), so no environment variable."
  type        = string
  default     = "platform"
}
