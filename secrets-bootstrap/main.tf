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

# ------------------------------------------------------------------
# KMS key for app secrets. Key rotation enabled. Key policy grants
# the root account full access and lets the ECS task execution role
# decrypt (so tasks can pull secrets at start).
#
# DeletionPolicy: Retain → prevent_destroy = true.
# ------------------------------------------------------------------

resource "aws_kms_key" "app_secrets" {
  description             = "Routebox ${var.environment} app secrets KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAM"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEcsTaskExecutionDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_execution_role_arn
        }
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "routebox-${var.environment}-app-secrets"
  }

  lifecycle { prevent_destroy = true }
}

resource "aws_kms_alias" "app_secrets" {
  name          = "alias/routebox-${var.environment}-app-secrets"
  target_key_id = aws_kms_key.app_secrets.key_id
}

# ------------------------------------------------------------------
# Baseline secrets. Every app expects these at boot. The resources
# create the secret name with a placeholder; real values are written
# by a platform engineer after the stack deploys (same as CFN).
#
# DeletionPolicy: Retain → prevent_destroy = true on all secrets.
# ------------------------------------------------------------------

resource "aws_secretsmanager_secret" "database_url" {
  name        = "routebox/${var.environment}/DATABASE_URL"
  description = "Postgres connection string. Written by hand after rds stack deploys."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/DATABASE_URL" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgres://placeholder:placeholder@placeholder:5432/routebox"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "internal_api_token" {
  name        = "routebox/${var.environment}/INTERNAL_API_TOKEN"
  description = "Shared bearer token for service-to-service calls (shipments-api <-> ops-console)."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/INTERNAL_API_TOKEN" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "internal_api_token" {
  secret_id     = aws_secretsmanager_secret.internal_api_token.id
  secret_string = "placeholder-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name        = "routebox/${var.environment}/JWT_SIGNING_KEY"
  description = "HS256 signing key for ops-console session tokens."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/JWT_SIGNING_KEY" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "jwt_signing_key" {
  secret_id     = aws_secretsmanager_secret.jwt_signing_key.id
  secret_string = "placeholder-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "carrier_webhook_signing_key" {
  name        = "routebox/${var.environment}/CARRIER_WEBHOOK_SIGNING_KEY"
  description = "HMAC key tracking-events uses to verify carrier webhook signatures."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/CARRIER_WEBHOOK_SIGNING_KEY" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "carrier_webhook_signing_key" {
  secret_id     = aws_secretsmanager_secret.carrier_webhook_signing_key.id
  secret_string = "placeholder-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "tracking_events_access_key_id" {
  # Long-lived AWS access key for the tracking-events IAM user. Yes.
  # Read notes/handover.md "tracking-events" for why. Rotated quarterly by Jenkins.
  name        = "routebox/${var.environment}/tracking-events/AWS_ACCESS_KEY_ID"
  description = "tracking-events long-lived access key id. Rotated quarterly by Jenkins."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/tracking-events/AWS_ACCESS_KEY_ID" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "tracking_events_access_key_id" {
  secret_id     = aws_secretsmanager_secret.tracking_events_access_key_id.id
  secret_string = "placeholder-AKIA-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "tracking_events_secret_access_key" {
  name        = "routebox/${var.environment}/tracking-events/AWS_SECRET_ACCESS_KEY"
  description = "tracking-events long-lived secret access key. Rotated quarterly by Jenkins."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/tracking-events/AWS_SECRET_ACCESS_KEY" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "tracking_events_secret_access_key" {
  secret_id     = aws_secretsmanager_secret.tracking_events_secret_access_key.id
  secret_string = "placeholder-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "smtp_password" {
  name        = "routebox/${var.environment}/SMTP_PASSWORD"
  description = "SES SMTP password used by ops-console for outbound email."
  kms_key_id  = aws_kms_key.app_secrets.arn

  tags = { Name = "routebox/${var.environment}/SMTP_PASSWORD" }

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "smtp_password" {
  secret_id     = aws_secretsmanager_secret.smtp_password.id
  secret_string = "placeholder-rotate-me"

  lifecycle { ignore_changes = [secret_string] }
}
