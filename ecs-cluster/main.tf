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
# ECS cluster. Container Insights enabled (matches CFN).
# ------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "routebox-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "routebox-${var.environment}"
  }
}

# ------------------------------------------------------------------
# Shared CloudWatch log group. All services stream to a prefix inside
# /routebox/<env>/ecs. Splitting per-service was discussed but never
# done — carried over from CFN as-is.
# ------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/routebox/${var.environment}/ecs"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/routebox/${var.environment}/ecs"
  }
}

# ------------------------------------------------------------------
# ALB. Internet-facing, in the public subnets, using the ALB SG
# from the network module.
# ------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "routebox-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "routebox-${var.environment}-alb"
  }
}

# ------------------------------------------------------------------
# Target groups — one per service.
#
# Note: rbx-<env>-<suffix> names match the CFN exactly. TG names are
# limited to 32 characters; the rbx prefix avoids hitting the limit
# that routebox-<env>-<suffix> would breach for longer env names.
# ------------------------------------------------------------------

resource "aws_lb_target_group" "shipments_api" {
  name        = "rbx-${var.environment}-shipments"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 8080
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Service = "shipments-api" }
}

resource "aws_lb_target_group" "route_optimizer" {
  # route-optimizer is SQS-driven, not HTTP. This TG exposes :9090/health
  # for the ALB to poke. No production traffic routes here.
  name        = "rbx-${var.environment}-routeopt"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 9090
  target_type = "ip"

  health_check {
    path    = "/health"
    matcher = "200"
  }

  tags = { Service = "route-optimizer" }
}

resource "aws_lb_target_group" "tracking_events" {
  name        = "rbx-${var.environment}-tracking"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 8081
  target_type = "ip"

  health_check {
    path    = "/healthz"
    matcher = "200"
  }

  tags = { Service = "tracking-events" }
}

resource "aws_lb_target_group" "customer_portal" {
  # Almost certainly unused — served from S3+CloudFront. Kept from when
  # we briefly planned to SSR it. Don't delete without checking with the
  # frontend team; removing would require editing the listener rules.
  name        = "rbx-${var.environment}-portal"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 3000
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200-399"
  }

  tags = { Service = "customer-portal" }
}

resource "aws_lb_target_group" "ops_console" {
  name        = "rbx-${var.environment}-opscon"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = 3000
  target_type = "ip"

  health_check {
    path    = "/up"
    matcher = "200"
  }

  tags = { Service = "ops-console" }
}

# ------------------------------------------------------------------
# Listeners. HTTP -> 301 redirect to HTTPS. HTTPS -> 404 default,
# then path/host-based rules per service.
# ------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "routebox: no route matched"
    }
  }
}

# ------------------------------------------------------------------
# Path/host-based listener rules. Priority order matches CFN exactly.
# ------------------------------------------------------------------

resource "aws_lb_listener_rule" "shipments_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shipments_api.arn
  }

  condition {
    path_pattern {
      # /internal/legacy-export is used by the data team for warehouse sync.
      # Don't remove without checking with them first.
      values = ["/api/shipments/*", "/api/v1/shipments/*", "/internal/legacy-export"]
    }
  }
}

resource "aws_lb_listener_rule" "route_optimizer" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.route_optimizer.arn
  }

  condition {
    path_pattern {
      values = ["/internal/route-optimizer/health"]
    }
  }
}

resource "aws_lb_listener_rule" "tracking_events" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tracking_events.arn
  }

  condition {
    path_pattern {
      values = ["/webhooks/carriers/*", "/webhooks/v2/*"]
    }
  }
}

resource "aws_lb_listener_rule" "ops_console" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ops_console.arn
  }

  condition {
    host_header {
      values = ["ops.${var.environment}.routebox.internal"]
    }
  }
}

resource "aws_lb_listener_rule" "customer_portal" {
  # In prod the Route 53 record points at CloudFront for portal.*, not the
  # ALB, so this rule effectively never fires. Kept for symmetry with CFN.
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.customer_portal.arn
  }

  condition {
    host_header {
      values = ["portal.${var.environment}.routebox.internal"]
    }
  }
}
