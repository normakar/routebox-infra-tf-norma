terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------
# Enhanced monitoring IAM role — looked up by the name the IAM CFN
# stack creates: routebox-<env>-rds-monitoring. Only resolved when
# monitoring_interval > 0 (i.e., prod).
# ------------------------------------------------------------------

data "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "routebox-${var.environment}-rds-monitoring"
}

# ------------------------------------------------------------------
# DB subnet group. Spans all three private subnets (one per AZ).
# Mirrors the CFN DbSubnetGroup which imported
# routebox-<env>-private-subnet-1/2/3 as cross-stack values.
# ------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "routebox-${var.environment}-db-subnets"
  description = "Routebox ${var.environment} private subnets for RDS"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name       = "routebox-${var.environment}-db-subnets"
    CostCenter = var.cost_center
  }
}

# ------------------------------------------------------------------
# Parameter group. Family postgres14 to match the pinned engine.
#
# IMPORTANT: prod has a hand-edit of max_connections = 400 that was
# never committed to the original CFN template. That value is now
# captured in var.max_connections (set in prod.tfvars). Re-apply it
# here — the first apply on prod will bring the parameter group in
# line with the live config.
# ------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name        = "routebox-${var.environment}-postgres14"
  family      = "postgres14"
  description = "Routebox ${var.environment} Postgres parameter group"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # idle_in_transaction_session_timeout is in milliseconds.
  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "600000"
  }

  # statement_timeout is in milliseconds.
  parameter {
    name  = "statement_timeout"
    value = "60000"
  }

  # max_connections: null = use RDS engine default (fine for dev/staging).
  # prod.tfvars sets this to 400 to match the hand-edit on the live CFN
  # parameter group. rds.force_ssl is left at its engine default (on) —
  # don't change it.
  dynamic "parameter" {
    for_each = var.max_connections != null ? [var.max_connections] : []
    content {
      name  = "max_connections"
      value = tostring(parameter.value)
    }
  }

  tags = {
    Name = "routebox-${var.environment}-postgres14"
  }

  lifecycle {
    # Replacing the parameter group requires the instance to be rebooted.
    # Force recreation of the group when parameters change rather than
    # attempting an in-place update, which can leave the instance in a
    # "pending reboot" state silently.
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------
# RDS instance. Ported verbatim from the CFN DbInstance.
#
# Notable decisions:
#  - StorageType gp3 (not gp2) — matches CFN.
#  - AutoMinorVersionUpgrade false — don't silently drift the patch
#    version; coordinate upgrades with ops-console (Rails constraint).
#  - PreferredBackupWindow / PreferredMaintenanceWindow kept from CFN.
#  - deletion_protection and performance_insights gated on prod via
#    variables (replaces the CFN IsProd condition).
#  - skip_final_snapshot = true for dev only; staging/prod take a
#    snapshot on destroy (mirrors CFN DeletionPolicy: Snapshot).
# ------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier        = "routebox-${var.environment}"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "routebox"
  username = var.db_master_username
  password = var.db_master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  multi_az               = var.multi_az
  publicly_accessible    = false
  copy_tags_to_snapshot  = true
  deletion_protection    = var.deletion_protection

  backup_retention_period   = var.backup_retention_days
  backup_window      = "06:00-06:30"
  maintenance_window = "sun:07:00-sun:07:30"

  auto_minor_version_upgrade = false

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "routebox-${var.environment}-final"

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_days : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? data.aws_iam_role.rds_monitoring[0].arn : null

  tags = {
    Name = "routebox-${var.environment}"
  }
}
