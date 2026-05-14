provider "aws" {
  region = var.aws_region

  # Replaces the per-resource Tags: blocks in the CFN template. Note
  # ManagedBy = "terraform" (was "cloudformation"). Resource-level Name
  # tags are still set inside the network module.
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = var.cost_center
    }
  }
}

module "network" {
  source = "../../network"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cost_center          = var.cost_center
  enable_nat_gateway   = var.enable_nat_gateway
}

module "rds" {
  source = "../../rds"

  environment           = var.environment
  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.network.rds_security_group_id
  cost_center           = var.cost_center

  db_instance_class    = var.rds_instance_class
  db_allocated_storage = var.rds_allocated_storage
  db_engine_version    = var.rds_engine_version
  db_master_username   = var.rds_master_username
  db_master_password   = var.rds_master_password
  multi_az             = var.rds_multi_az
  backup_retention_days = var.rds_backup_retention_days

  deletion_protection          = var.rds_deletion_protection
  performance_insights_enabled = var.rds_performance_insights_enabled
  monitoring_interval          = var.rds_monitoring_interval
  skip_final_snapshot          = var.rds_skip_final_snapshot
  max_connections              = var.rds_max_connections
}

# module "eks" {
#   source = "../../eks"

#   environment                  = var.environment
#   vpc_id                       = module.network.vpc_id
#   public_subnet_ids            = module.network.public_subnet_ids
#   kubernetes_version           = var.eks_kubernetes_version
#   endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
#   node_instance_types          = var.eks_node_instance_types
#   node_capacity_type           = var.eks_node_capacity_type
#   node_disk_size_gb            = var.eks_node_disk_size_gb
#   node_min_size                = var.eks_node_min_size
#   node_desired_size            = var.eks_node_desired_size
#   node_max_size                = var.eks_node_max_size
#   cluster_admin_role_arns      = var.eks_cluster_admin_role_arns
#   cost_center                  = var.cost_center
# }
