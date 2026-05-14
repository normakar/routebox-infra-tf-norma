output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN. Equivalent to CFN export routebox-<env>-ecs-task-execution-role-arn."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "shipments_api_role_arn" {
  description = "shipments-api task role ARN."
  value       = aws_iam_role.shipments_api.arn
}

output "route_optimizer_role_arn" {
  description = "route-optimizer task role ARN."
  value       = aws_iam_role.route_optimizer.arn
}

output "customer_portal_role_arn" {
  description = "customer-portal task role ARN."
  value       = aws_iam_role.customer_portal.arn
}

output "ops_console_role_arn" {
  description = "ops-console task role ARN."
  value       = aws_iam_role.ops_console.arn
}

output "jenkins_role_arn" {
  description = "Jenkins instance role ARN."
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_instance_profile_arn" {
  description = "Jenkins EC2 instance profile ARN."
  value       = aws_iam_instance_profile.jenkins.arn
}

output "rds_monitoring_role_arn" {
  description = "RDS enhanced monitoring role ARN. When the IAM stack is active, the rds module's data source resolves to this role."
  value       = aws_iam_role.rds_monitoring.arn
}
