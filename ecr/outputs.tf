output "shipments_api_repo_uri" {
  description = "shipments-api ECR repository URI. Equivalent to CFN export routebox-ecr-shipments-api-uri."
  value       = aws_ecr_repository.shipments_api.repository_url
}

output "route_optimizer_repo_uri" {
  description = "route-optimizer ECR repository URI."
  value       = aws_ecr_repository.route_optimizer.repository_url
}

output "tracking_events_repo_uri" {
  description = "tracking-events ECR repository URI."
  value       = aws_ecr_repository.tracking_events.repository_url
}

output "customer_portal_repo_uri" {
  description = "customer-portal ECR repository URI."
  value       = aws_ecr_repository.customer_portal.repository_url
}

output "ops_console_repo_uri" {
  description = "ops-console ECR repository URI."
  value       = aws_ecr_repository.ops_console.repository_url
}
