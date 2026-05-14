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
# ECR repos are NOT per-environment — one set serves all envs.
# Different image tags differentiate (latest, prod, staging, dev).
# This module is called from environments/prod/ only, mirroring how
# the CFN stack was deployed: once, against prod.
#
# DeletionPolicy: Retain in CFN → prevent_destroy = true here.
# Deleting the TF module call will leave the repos in place rather
# than destroying them (which would break all deploys).
# ------------------------------------------------------------------

locals {
  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 200 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 200
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_repository" "shipments_api" {
  name                 = "routebox-shipments-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Service = "shipments-api", CostCenter = var.cost_center }

  lifecycle { prevent_destroy = true }
}

resource "aws_ecr_lifecycle_policy" "shipments_api" {
  repository = aws_ecr_repository.shipments_api.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_repository" "route_optimizer" {
  name                 = "routebox-route-optimizer"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Service = "route-optimizer", CostCenter = var.cost_center }

  lifecycle { prevent_destroy = true }
}

resource "aws_ecr_lifecycle_policy" "route_optimizer" {
  repository = aws_ecr_repository.route_optimizer.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_repository" "tracking_events" {
  name                 = "routebox-tracking-events"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Service = "tracking-events", CostCenter = var.cost_center }

  lifecycle { prevent_destroy = true }
}

resource "aws_ecr_repository" "customer_portal" {
  name                 = "routebox-customer-portal"
  image_tag_mutability = "MUTABLE"

  # ScanOnPush = false in CFN — customer-portal is an SPA; scanning is
  # less useful than for backend images.
  image_scanning_configuration {
    scan_on_push = false
  }

  tags = { Service = "customer-portal", CostCenter = var.cost_center }

  lifecycle { prevent_destroy = true }
}

resource "aws_ecr_repository" "ops_console" {
  name                 = "routebox-ops-console"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Service = "ops-console", CostCenter = var.cost_center }

  lifecycle { prevent_destroy = true }
}
