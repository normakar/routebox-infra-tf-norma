environment = "prod"
aws_region  = "us-east-2"
cost_center = "platform-prod"

vpc_cidr = "10.30.0.0/16"

public_subnet_cidrs = [
  "10.30.0.0/22",
  "10.30.4.0/22",
  "10.30.8.0/22",
]

private_subnet_cidrs = [
  "10.30.16.0/20",
  "10.30.32.0/20",
  "10.30.48.0/20",
]

enable_nat_gateway = true # prod has NAT — private subnets need egress

# ------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------

rds_instance_class    = "db.m5.xlarge"
rds_allocated_storage = 500
rds_engine_version    = "14.23"
rds_master_username   = "routebox_admin"
# rds_master_password: pull from 1Password at apply time and pass via
# TF_VAR_rds_master_password. Do not commit the real value here.
rds_master_password = "ChangeMe-prod-pulled-from-1pw-at-deploy-time"

rds_multi_az              = true
rds_backup_retention_days = 30

rds_deletion_protection                  = true
rds_performance_insights_enabled         = true
rds_performance_insights_retention_days  = 7
rds_monitoring_interval                  = 60
rds_skip_final_snapshot                  = false

# max_connections: captures the hand-edit on the live CFN parameter group
# (=400) that was never committed back to the CFN template. First apply
# will bring the TF-managed parameter group in line with the live config.
rds_max_connections = 400

# ------------------------------------------------------------------
# ECS cluster
# ------------------------------------------------------------------

# Replace with the real ACM cert ARN before applying.
acm_certificate_arn = "arn:aws:acm:us-east-1:111122223333:certificate/prod-placeholder-replace-me"
log_retention_days  = 90

# ------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------

eks_kubernetes_version           = "1.35"
eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]
eks_node_instance_types          = ["t3.large"]
eks_node_capacity_type           = "ON_DEMAND"
eks_node_disk_size_gb            = 50
eks_node_min_size                = 2
eks_node_desired_size            = 3
eks_node_max_size                = 10

eks_cluster_admin_role_arns = [
  "arn:aws:iam::834786370659:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_Administrator_26e5753d72bb56b0",
]
