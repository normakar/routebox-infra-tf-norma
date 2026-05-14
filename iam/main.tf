terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ------------------------------------------------------------------
# ECS task execution role. One per environment, shared by every
# service. AWS-managed policy covers ECR pulls + CW logs; inline
# policy adds Secrets Manager read so the agent can pull secrets
# at task start.
# ------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name = "routebox-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  inline_policy {
    name = "read-bootstrap-secrets"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        # TODO scope this down to routebox/* prefix only.
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
        Resource = "*"
      }]
    })
  }

  tags = { Environment = var.environment }
}

# ------------------------------------------------------------------
# Per-service ECS task roles.
# ------------------------------------------------------------------

resource "aws_iam_role" "shipments_api" {
  name = "routebox-${var.environment}-shipments-api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "shipments-api-runtime"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # SQS publish for the routing queue. Hardcoded ARN — queue lives
          # outside CFN, created during a Friday incident. Don't rename without
          # updating here too.
          Effect   = "Allow"
          Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
          Resource = "arn:aws:sqs:${local.region}:${local.account_id}:routebox-route-calc-queue"
        },
        {
          # S3 for the legacy-export endpoint. TODO scope to export prefix.
          Effect   = "Allow"
          Action   = ["s3:PutObject", "s3:GetObject"]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:routebox/${var.environment}/*"
        }
      ]
    })
  }

  tags = { Environment = var.environment, Service = "shipments-api" }
}

resource "aws_iam_role" "route_optimizer" {
  name = "routebox-${var.environment}-route-optimizer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "route-optimizer-sqs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl", "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${local.region}:${local.account_id}:routebox-route-calc-queue"
      }]
    })
  }

  inline_policy {
    name = "route-optimizer-secrets"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:routebox/${var.environment}/*"
      }]
    })
  }

  inline_policy {
    name = "route-optimizer-cw"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "routebox/${var.environment}/route-optimizer"
          }
        }
      }]
    })
  }

  tags = { Environment = var.environment, Service = "route-optimizer" }
}

resource "aws_iam_role" "customer_portal" {
  # NOTE: customer-portal is an SPA served from S3+CloudFront. This role
  # was kept from when we briefly considered SSR from a Node container. It's
  # attached to nothing today. Don't delete without checking with the frontend team.
  name = "routebox-${var.environment}-customer-portal"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "customer-portal-s3-sync"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetObject"]
          Resource = [
            "arn:aws:s3:::routebox-customer-portal-prod",
            "arn:aws:s3:::routebox-customer-portal-prod/*",
            "arn:aws:s3:::routebox-customer-portal-staging",
            "arn:aws:s3:::routebox-customer-portal-staging/*",
            "arn:aws:s3:::routebox-customer-portal-dev",
            "arn:aws:s3:::routebox-customer-portal-dev/*",
          ]
        },
        {
          # TODO scope to the customer-portal distribution for this env only.
          Effect   = "Allow"
          Action   = ["cloudfront:CreateInvalidation"]
          Resource = "*"
        }
      ]
    })
  }

  tags = { Environment = var.environment, Service = "customer-portal" }
}

resource "aws_iam_role" "ops_console" {
  name = "routebox-${var.environment}-ops-console"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "ops-console-runtime"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:routebox/${var.environment}/*"
        },
        {
          # SES for password resets and internal alerts. TODO scope this down.
          Effect   = "Allow"
          Action   = ["ses:SendEmail", "ses:SendRawEmail"]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = ["arn:aws:s3:::routebox-shipments-exports", "arn:aws:s3:::routebox-shipments-exports/*"]
        }
      ]
    })
  }

  tags = { Environment = var.environment, Service = "ops-console" }
}

# ------------------------------------------------------------------
# Jenkins instance role + profile. EC2 trust — TODO scope to the
# specific Jenkins instance. Wide because we never came back to it
# after the AMI rebuild.
# ------------------------------------------------------------------

resource "aws_iam_role" "jenkins" {
  name = "routebox-${var.environment}-jenkins"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      # TODO scope to the specific Jenkins EC2 instance.
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "jenkins-ecr-push"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload",
            "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload",
            "ecr:PutImage", "ecr:UploadLayerPart",
            "ecr:DescribeRepositories", "ecr:DescribeImages"
          ]
          # Five ECR repos. Hardcoded ARNs — this stack predates the ecr stack's exports.
          Resource = [
            "arn:aws:ecr:${local.region}:${local.account_id}:repository/routebox-shipments-api",
            "arn:aws:ecr:${local.region}:${local.account_id}:repository/routebox-route-optimizer",
            "arn:aws:ecr:${local.region}:${local.account_id}:repository/routebox-tracking-events",
            "arn:aws:ecr:${local.region}:${local.account_id}:repository/routebox-customer-portal",
            "arn:aws:ecr:${local.region}:${local.account_id}:repository/routebox-ops-console",
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "jenkins-ecs-deploy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # TODO scope to routebox-* clusters and services.
          Effect = "Allow"
          Action = [
            "ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:DescribeTasks",
            "ecs:ListTasks", "ecs:RegisterTaskDefinition", "ecs:UpdateService",
            "ecs:DeregisterTaskDefinition"
          ]
          Resource = "*"
        },
        {
          # TODO scope to routebox-${env}-* roles.
          Effect   = "Allow"
          Action   = ["iam:PassRole"]
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name = "jenkins-rotate-tracking-events-keys"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # IAM user is shared across all envs — same user, not per-env.
          Effect   = "Allow"
          Action   = ["iam:CreateAccessKey", "iam:DeleteAccessKey", "iam:ListAccessKeys", "iam:UpdateAccessKey"]
          Resource = "arn:aws:iam::${local.account_id}:user/routebox-tracking-events"
        },
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret"]
          Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:routebox/${var.environment}/tracking-events/*"
        }
      ]
    })
  }

  inline_policy {
    name = "jenkins-s3-customer-portal-sync"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetObject"]
          Resource = [
            "arn:aws:s3:::routebox-customer-portal-prod",
            "arn:aws:s3:::routebox-customer-portal-prod/*",
            "arn:aws:s3:::routebox-customer-portal-staging",
            "arn:aws:s3:::routebox-customer-portal-staging/*",
            "arn:aws:s3:::routebox-customer-portal-dev",
            "arn:aws:s3:::routebox-customer-portal-dev/*",
          ]
        },
        {
          # TODO scope to the customer-portal distribution.
          Effect   = "Allow"
          Action   = ["cloudfront:CreateInvalidation"]
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name = "jenkins-cloudwatch-logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "*"
      }]
    })
  }

  inline_policy {
    name = "jenkins-secrets-read"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        # TODO scope to routebox/* only.
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecrets"]
        Resource = "*"
      }]
    })
  }

  tags = { Environment = var.environment, Component = "jenkins" }
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "routebox-${var.environment}-jenkins"
  role = aws_iam_role.jenkins.name
}

# ------------------------------------------------------------------
# RDS enhanced monitoring role. AWS-managed policy only.
# ------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  name = "routebox-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]

  tags = { Environment = var.environment }
}
