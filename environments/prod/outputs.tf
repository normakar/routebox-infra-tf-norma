output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "All three public subnet IDs, [a, b, c] order."
  value       = module.network.public_subnet_ids
}

output "public_subnet_1_id" {
  description = "Public subnet in AZ a."
  value       = module.network.public_subnet_1_id
}

output "public_subnet_2_id" {
  description = "Public subnet in AZ b."
  value       = module.network.public_subnet_2_id
}

output "public_subnet_3_id" {
  description = "Public subnet in AZ c."
  value       = module.network.public_subnet_3_id
}

output "private_subnet_ids" {
  description = "All three private subnet IDs, [a, b, c] order."
  value       = module.network.private_subnet_ids
}

output "private_subnet_1_id" {
  description = "Private subnet in AZ a."
  value       = module.network.private_subnet_1_id
}

output "private_subnet_2_id" {
  description = "Private subnet in AZ b."
  value       = module.network.private_subnet_2_id
}

output "private_subnet_3_id" {
  description = "Private subnet in AZ c."
  value       = module.network.private_subnet_3_id
}

output "alb_security_group_id" {
  description = "Public ALB SG ID."
  value       = module.network.alb_security_group_id
}

output "ecs_service_security_group_id" {
  description = "ECS service tasks SG ID."
  value       = module.network.ecs_service_security_group_id
}

output "rds_security_group_id" {
  description = "RDS Postgres SG ID."
  value       = module.network.rds_security_group_id
}

output "jenkins_security_group_id" {
  description = "Jenkins EC2 SG ID."
  value       = module.network.jenkins_security_group_id
}

# ------------------------------------------------------------------
# Legacy CFN export names intentionally omitted:
#   - prod-vpc               (grandfathered from before routebox-<env>-<resource> convention)
#   - prod-subnet-private-a  (same)
# Any stack still consuming these names via CFN cross-stack imports
# must be updated to use the outputs above before this module can
# fully replace the CFN network stack.
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# EKS — re-export the module's outputs so consumers (kubeconfig
# helpers, IRSA wiring, follow-up modules) can read them off this
# stack's state without going inside the module.
# ------------------------------------------------------------------

# output "cluster_name" {
#   description = "EKS cluster name."
#   value       = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   description = "Kubernetes API server endpoint."
#   value       = module.eks.cluster_endpoint
# }

# output "cluster_certificate_authority_data" {
#   description = "Base64-encoded cluster CA cert."
#   value       = module.eks.cluster_certificate_authority_data
#   sensitive   = true
# }

# output "cluster_oidc_issuer_url" {
#   description = "OIDC issuer URL for IRSA."
#   value       = module.eks.cluster_oidc_issuer_url
# }

# output "cluster_security_group_id" {
#   description = "EKS-managed cluster SG ID."
#   value       = module.eks.cluster_security_group_id
# }

# output "node_security_group_id" {
#   description = "Node SG ID. Same as cluster SG in this configuration."
#   value       = module.eks.node_security_group_id
# }

# output "oidc_provider_arn" {
#   description = "IRSA OIDC provider ARN."
#   value       = module.eks.oidc_provider_arn
# }

# output "kms_key_arn" {
#   description = "KMS key ARN used for K8s secrets envelope encryption."
#   value       = module.eks.kms_key_arn
# }
