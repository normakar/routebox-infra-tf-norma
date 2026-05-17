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
# RDS
# ------------------------------------------------------------------

output "db_endpoint" {
  description = "RDS instance endpoint hostname."
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "RDS instance port."
  value       = module.rds.db_port
}

output "db_instance_identifier" {
  description = "RDS instance identifier."
  value       = module.rds.db_instance_identifier
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
# IAM
# ------------------------------------------------------------------

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = module.iam.ecs_task_execution_role_arn
}

output "shipments_api_role_arn" {
  description = "Shipments API task role ARN."
  value       = module.iam.shipments_api_role_arn
}

output "route_optimizer_role_arn" {
  description = "Route optimizer task role ARN."
  value       = module.iam.route_optimizer_role_arn
}

output "customer_portal_role_arn" {
  description = "Customer portal task role ARN."
  value       = module.iam.customer_portal_role_arn
}

output "ops_console_role_arn" {
  description = "Ops console task role ARN."
  value       = module.iam.ops_console_role_arn
}

output "jenkins_role_arn" {
  description = "Jenkins EC2 instance role ARN."
  value       = module.iam.jenkins_role_arn
}

output "jenkins_instance_profile_arn" {
  description = "Jenkins EC2 instance profile ARN."
  value       = module.iam.jenkins_instance_profile_arn
}

output "rds_monitoring_role_arn" {
  description = "RDS enhanced monitoring role ARN."
  value       = module.iam.rds_monitoring_role_arn
}

# ------------------------------------------------------------------
# ECS cluster — disabled until a valid ACM certificate exists for prod.
# ------------------------------------------------------------------

# output "cluster_arn" {
#   description = "ECS cluster ARN."
#   value       = module.ecs_cluster.cluster_arn
# }
#
# output "cluster_name" {
#   description = "ECS cluster name."
#   value       = module.ecs_cluster.cluster_name
# }
#
# output "alb_arn" {
#   description = "ALB ARN."
#   value       = module.ecs_cluster.alb_arn
# }
#
# output "alb_dns_name" {
#   description = "ALB DNS name."
#   value       = module.ecs_cluster.alb_dns_name
# }
#
# output "alb_zone_id" {
#   description = "ALB hosted zone ID (for Route 53 alias records)."
#   value       = module.ecs_cluster.alb_zone_id
# }
#
# output "https_listener_arn" {
#   description = "HTTPS listener ARN."
#   value       = module.ecs_cluster.https_listener_arn
# }
#
# output "shipments_api_tg_arn" {
#   description = "Shipments API target group ARN."
#   value       = module.ecs_cluster.shipments_api_tg_arn
# }
#
# output "route_optimizer_tg_arn" {
#   description = "Route optimizer target group ARN."
#   value       = module.ecs_cluster.route_optimizer_tg_arn
# }
#
# output "tracking_events_tg_arn" {
#   description = "Tracking events target group ARN."
#   value       = module.ecs_cluster.tracking_events_tg_arn
# }
#
# output "customer_portal_tg_arn" {
#   description = "Customer portal target group ARN."
#   value       = module.ecs_cluster.customer_portal_tg_arn
# }
#
# output "ops_console_tg_arn" {
#   description = "Ops console target group ARN."
#   value       = module.ecs_cluster.ops_console_tg_arn
# }
#
# output "log_group_name" {
#   description = "CloudWatch log group name for ECS cluster."
#   value       = module.ecs_cluster.log_group_name
# }

# ------------------------------------------------------------------
# Secrets bootstrap
# ------------------------------------------------------------------

output "app_secrets_kms_key_id" {
  description = "KMS key ID used to encrypt app secrets."
  value       = module.secrets_bootstrap.app_secrets_key_id
}

output "app_secrets_kms_key_arn" {
  description = "KMS key ARN used to encrypt app secrets."
  value       = module.secrets_bootstrap.app_secrets_key_arn
}

output "database_url_secret_arn" {
  description = "Secrets Manager ARN for the DATABASE_URL secret."
  value       = module.secrets_bootstrap.database_url_secret_arn
}

output "internal_api_token_secret_arn" {
  description = "Secrets Manager ARN for the INTERNAL_API_TOKEN secret."
  value       = module.secrets_bootstrap.internal_api_token_secret_arn
}

output "jwt_signing_key_secret_arn" {
  description = "Secrets Manager ARN for the JWT_SIGNING_KEY secret."
  value       = module.secrets_bootstrap.jwt_signing_key_secret_arn
}

output "carrier_webhook_signing_key_secret_arn" {
  description = "Secrets Manager ARN for the CARRIER_WEBHOOK_SIGNING_KEY secret."
  value       = module.secrets_bootstrap.carrier_webhook_signing_key_secret_arn
}

# ------------------------------------------------------------------
# ECR (prod only — repos are global, managed here)
# ------------------------------------------------------------------

output "shipments_api_repo_uri" {
  description = "Shipments API ECR repository URI."
  value       = module.ecr.shipments_api_repo_uri
}

output "route_optimizer_repo_uri" {
  description = "Route optimizer ECR repository URI."
  value       = module.ecr.route_optimizer_repo_uri
}

output "tracking_events_repo_uri" {
  description = "Tracking events ECR repository URI."
  value       = module.ecr.tracking_events_repo_uri
}

output "customer_portal_repo_uri" {
  description = "Customer portal ECR repository URI."
  value       = module.ecr.customer_portal_repo_uri
}

output "ops_console_repo_uri" {
  description = "Ops console ECR repository URI."
  value       = module.ecr.ops_console_repo_uri
}

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

# output "cluster_autoscaler_role_arn" {
#   description = "IRSA role ARN for the cluster autoscaler Helm chart. Pass as serviceAccount.annotations.eks.amazonaws.com/role-arn."
#   value       = module.eks.cluster_autoscaler_role_arn
# }
