output "cluster_arn" {
  description = "ECS cluster ARN. Equivalent to CFN export routebox-<env>-ecs-cluster-arn."
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECS cluster name. Equivalent to CFN export routebox-<env>-ecs-cluster-name."
  value       = aws_ecs_cluster.main.name
}

output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name. Equivalent to CFN export routebox-<env>-alb-dns."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB canonical hosted zone ID (for Route 53 alias records)."
  value       = aws_lb.main.zone_id
}

output "https_listener_arn" {
  description = "HTTPS listener ARN. Equivalent to CFN export routebox-<env>-alb-https-listener."
  value       = aws_lb_listener.https.arn
}

output "shipments_api_tg_arn" {
  description = "shipments-api target group ARN."
  value       = aws_lb_target_group.shipments_api.arn
}

output "route_optimizer_tg_arn" {
  description = "route-optimizer target group ARN."
  value       = aws_lb_target_group.route_optimizer.arn
}

output "tracking_events_tg_arn" {
  description = "tracking-events target group ARN."
  value       = aws_lb_target_group.tracking_events.arn
}

output "customer_portal_tg_arn" {
  description = "customer-portal target group ARN."
  value       = aws_lb_target_group.customer_portal.arn
}

output "ops_console_tg_arn" {
  description = "ops-console target group ARN."
  value       = aws_lb_target_group.ops_console.arn
}

output "log_group_name" {
  description = "Shared ECS CloudWatch log group name."
  value       = aws_cloudwatch_log_group.ecs.name
}
