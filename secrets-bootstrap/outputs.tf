output "app_secrets_key_id" {
  description = "KMS key ID for app secrets. Equivalent to CFN export routebox-<env>-app-secrets-key-id."
  value       = aws_kms_key.app_secrets.key_id
}

output "app_secrets_key_arn" {
  description = "KMS key ARN for app secrets."
  value       = aws_kms_key.app_secrets.arn
}

output "database_url_secret_arn" {
  description = "DATABASE_URL secret ARN."
  value       = aws_secretsmanager_secret.database_url.arn
}

output "internal_api_token_secret_arn" {
  description = "INTERNAL_API_TOKEN secret ARN."
  value       = aws_secretsmanager_secret.internal_api_token.arn
}

output "jwt_signing_key_secret_arn" {
  description = "JWT_SIGNING_KEY secret ARN."
  value       = aws_secretsmanager_secret.jwt_signing_key.arn
}

output "carrier_webhook_signing_key_secret_arn" {
  description = "CARRIER_WEBHOOK_SIGNING_KEY secret ARN."
  value       = aws_secretsmanager_secret.carrier_webhook_signing_key.arn
}
