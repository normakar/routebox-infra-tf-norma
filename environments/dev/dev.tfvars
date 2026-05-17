#just a comment
environment = "dev"
aws_region  = "us-east-2"
cost_center = "platform-dev"

vpc_cidr = "10.10.0.0/16"

public_subnet_cidrs = [
  "10.10.0.0/22",
  "10.10.4.0/22",
  "10.10.8.0/22",
]

# Kept even though private subnets are currently egress-less. They
# stay reserved as a future option once we have something that needs
# isolation from the internet.
private_subnet_cidrs = [
  "10.10.16.0/20",
  "10.10.32.0/20",
  "10.10.48.0/20",
]

enable_nat_gateway = false

# ------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------

rds_instance_class    = "db.t3.small"
rds_allocated_storage = 20
rds_engine_version    = "14.23"
rds_master_username   = "routebox_admin"
# rds_master_password: set via TF_VAR_rds_master_password env var at apply time.
# export TF_VAR_rds_master_password="..."

rds_multi_az              = false
rds_backup_retention_days = 1

rds_deletion_protection          = false
rds_performance_insights_enabled = false
rds_monitoring_interval          = 0
rds_skip_final_snapshot          = true # dev — no need to keep a final snapshot

# ------------------------------------------------------------------
# ECS cluster
# ------------------------------------------------------------------

# Replace with the real ACM cert ARN before applying.
acm_certificate_arn = "arn:aws:acm:us-east-2:218550331401:certificate/12d185a6-7cf9-48d6-955e-36420de59c32"
log_retention_days  = 7

# ------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------

eks_kubernetes_version           = "1.35"
eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]
eks_node_instance_types          = ["t3.medium"]
# Recommended sizes when workloads grow:
# eks_node_instance_types = ["t3.large"]           # general purpose
# eks_node_instance_types = ["m5.large"]           # memory-bound workloads
eks_node_capacity_type = "SPOT"
eks_node_disk_size_gb  = 20
eks_node_min_size      = 2
eks_node_desired_size  = 2
eks_node_max_size      = 4

eks_cluster_admin_role_arns = [
  "arn:aws:iam::834786370659:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_Administrator_26e5753d72bb56b0",
]
