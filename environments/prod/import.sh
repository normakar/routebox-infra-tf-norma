#!/usr/bin/env bash
# Import existing CFN-managed prod resources into Terraform state.
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials.
#   - Terraform >= 1.10 installed.
#   - S3 bucket routebox-tfstate-prod exists (versioning + encryption).
#   - `acm_certificate_arn` in prod.tfvars replaced with the real ARN.
#   - Run from the environments/prod/ directory after `terraform init`.
#
# Usage:
#   export TF_VAR_rds_master_password="<real-password>"
#   bash import.sh
#
# Prod differences vs staging:
#   - enable_nat_gateway = true → NAT resources are included (same as staging).
#   - rds_monitoring_interval = 60 → RDS monitoring role IS used by the instance.
#   - module.ecr manages 5 ECR repos (global, prod root module only).
#   - deletion_protection = true on RDS — plan will show no change to this.
#
# CAUTION: This imports live production resources. Run terraform plan and
# review all diffs carefully before terraform apply.

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ENV="prod"

TF_IMPORT_PASS="${TF_VAR_rds_master_password:?TF_VAR_rds_master_password must be set}"

TF() {
  terraform import \
    -var-file="${ENV}.tfvars" \
    -var="rds_master_password=${TF_IMPORT_PASS}" \
    "$@"
}

# ============================================================
# 1. Network
# ============================================================

echo "==> [1/6] Resolving network resource IDs from AWS..."

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-vpc" \
  --query 'Vpcs[0].VpcId' --output text)
echo "    vpc: $VPC_ID"

IGW_ID=$(aws ec2 describe-internet-gateways --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-igw" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)

PUBLIC_SN_A=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-public-a" \
  --query 'Subnets[0].SubnetId' --output text)
PUBLIC_SN_B=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-public-b" \
  --query 'Subnets[0].SubnetId' --output text)
PUBLIC_SN_C=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-public-c" \
  --query 'Subnets[0].SubnetId' --output text)
echo "    public subnets: $PUBLIC_SN_A  $PUBLIC_SN_B  $PUBLIC_SN_C"

PRIVATE_SN_A=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-private-a" \
  --query 'Subnets[0].SubnetId' --output text)
PRIVATE_SN_B=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-private-b" \
  --query 'Subnets[0].SubnetId' --output text)
PRIVATE_SN_C=$(aws ec2 describe-subnets --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-private-c" \
  --query 'Subnets[0].SubnetId' --output text)
echo "    private subnets: $PRIVATE_SN_A  $PRIVATE_SN_B  $PRIVATE_SN_C"

NAT_EIP_ALLOC=$(aws ec2 describe-addresses --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-nat-eip" \
  --query 'Addresses[0].AllocationId' --output text)
echo "    nat eip: $NAT_EIP_ALLOC"

NAT_GW_ID=$(aws ec2 describe-nat-gateways --region "$REGION" \
  --filter "Name=tag:Name,Values=routebox-${ENV}-nat" \
  --query 'NatGateways[?State!=`deleted`] | [0].NatGatewayId' --output text)
echo "    nat gw: $NAT_GW_ID"

PUBLIC_RT_ID=$(aws ec2 describe-route-tables --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-public-rt" \
  --query 'RouteTables[0].RouteTableId' --output text)
PRIVATE_RT_ID=$(aws ec2 describe-route-tables --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-private-rt" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "    route tables: $PUBLIC_RT_ID  $PRIVATE_RT_ID"

ALB_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-alb-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
ECS_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-ecs-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
RDS_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-rds-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
JENKINS_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=tag:Name,Values=routebox-${ENV}-jenkins-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
echo "    security groups: alb=$ALB_SG_ID  ecs=$ECS_SG_ID  rds=$RDS_SG_ID  jenkins=$JENKINS_SG_ID"

ECS_FROM_ALB_RULE=$(aws ec2 describe-security-group-rules --region "$REGION" \
  --filters "Name=group-id,Values=$ECS_SG_ID" "Name=is-egress,Values=false" \
  --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)
RDS_FROM_ECS_RULE=$(aws ec2 describe-security-group-rules --region "$REGION" \
  --filters "Name=group-id,Values=$RDS_SG_ID" "Name=is-egress,Values=false" \
  --query "SecurityGroupRules[?ReferencedGroupInfo.GroupId=='${ECS_SG_ID}'] | [0].SecurityGroupRuleId" \
  --output text)
RDS_FROM_JENKINS_RULE=$(aws ec2 describe-security-group-rules --region "$REGION" \
  --filters "Name=group-id,Values=$RDS_SG_ID" "Name=is-egress,Values=false" \
  --query "SecurityGroupRules[?ReferencedGroupInfo.GroupId=='${JENKINS_SG_ID}'] | [0].SecurityGroupRuleId" \
  --output text)
echo "    sg ingress rules: ecs_from_alb=$ECS_FROM_ALB_RULE  rds_from_ecs=$RDS_FROM_ECS_RULE  rds_from_jenkins=$RDS_FROM_JENKINS_RULE"

echo "==> [1/6] Importing network resources..."

TF 'module.network.aws_vpc.main'                                         "$VPC_ID"
TF 'module.network.aws_internet_gateway.main'                            "$IGW_ID"
TF 'module.network.aws_subnet.public[0]'                                 "$PUBLIC_SN_A"
TF 'module.network.aws_subnet.public[1]'                                 "$PUBLIC_SN_B"
TF 'module.network.aws_subnet.public[2]'                                 "$PUBLIC_SN_C"
TF 'module.network.aws_subnet.private[0]'                                "$PRIVATE_SN_A"
TF 'module.network.aws_subnet.private[1]'                                "$PRIVATE_SN_B"
TF 'module.network.aws_subnet.private[2]'                                "$PRIVATE_SN_C"
TF 'module.network.aws_eip.nat[0]'                                       "$NAT_EIP_ALLOC"
TF 'module.network.aws_nat_gateway.main[0]'                              "$NAT_GW_ID"
TF 'module.network.aws_route_table.public'                               "$PUBLIC_RT_ID"
TF 'module.network.aws_route.public_default'                             "${PUBLIC_RT_ID}_0.0.0.0/0"
TF 'module.network.aws_route_table_association.public[0]'                "${PUBLIC_SN_A}/${PUBLIC_RT_ID}"
TF 'module.network.aws_route_table_association.public[1]'                "${PUBLIC_SN_B}/${PUBLIC_RT_ID}"
TF 'module.network.aws_route_table_association.public[2]'                "${PUBLIC_SN_C}/${PUBLIC_RT_ID}"
TF 'module.network.aws_route_table.private'                              "$PRIVATE_RT_ID"
TF 'module.network.aws_route.private_default[0]'                         "${PRIVATE_RT_ID}_0.0.0.0/0"
TF 'module.network.aws_route_table_association.private[0]'               "${PRIVATE_SN_A}/${PRIVATE_RT_ID}"
TF 'module.network.aws_route_table_association.private[1]'               "${PRIVATE_SN_B}/${PRIVATE_RT_ID}"
TF 'module.network.aws_route_table_association.private[2]'               "${PRIVATE_SN_C}/${PRIVATE_RT_ID}"
TF 'module.network.aws_security_group.alb'                               "$ALB_SG_ID"
TF 'module.network.aws_security_group.ecs'                               "$ECS_SG_ID"
TF 'module.network.aws_vpc_security_group_ingress_rule.ecs_from_alb'     "$ECS_FROM_ALB_RULE"
TF 'module.network.aws_security_group.rds'                               "$RDS_SG_ID"
TF 'module.network.aws_vpc_security_group_ingress_rule.rds_from_ecs'     "$RDS_FROM_ECS_RULE"
TF 'module.network.aws_security_group.jenkins'                           "$JENKINS_SG_ID"
TF 'module.network.aws_vpc_security_group_ingress_rule.rds_from_jenkins' "$RDS_FROM_JENKINS_RULE"

# ============================================================
# 2. RDS
# ============================================================

echo "==> [2/6] Resolving RDS resource IDs from AWS..."

DB_PARAM_GROUP=$(aws rds describe-db-instances --region "$REGION" \
  --db-instance-identifier "routebox-${ENV}" \
  --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' --output text)
echo "    parameter group: $DB_PARAM_GROUP"

echo "==> [2/6] Importing RDS resources..."

TF 'module.rds.aws_db_subnet_group.main'    "routebox-${ENV}-db-subnets"
TF 'module.rds.aws_db_parameter_group.main' "$DB_PARAM_GROUP"
TF 'module.rds.aws_db_instance.main'        "routebox-${ENV}"

# ============================================================
# 3. IAM
# ============================================================

echo "==> [3/6] Importing IAM resources..."

TF 'module.iam.aws_iam_role.ecs_task_execution' "routebox-${ENV}-ecs-task-execution"
TF 'module.iam.aws_iam_role.shipments_api'       "routebox-${ENV}-shipments-api"
TF 'module.iam.aws_iam_role.route_optimizer'     "routebox-${ENV}-route-optimizer"
TF 'module.iam.aws_iam_role.customer_portal'     "routebox-${ENV}-customer-portal"
TF 'module.iam.aws_iam_role.ops_console'         "routebox-${ENV}-ops-console"
TF 'module.iam.aws_iam_role.jenkins'             "routebox-${ENV}-jenkins"
TF 'module.iam.aws_iam_instance_profile.jenkins' "routebox-${ENV}-jenkins"
TF 'module.iam.aws_iam_role.rds_monitoring'      "routebox-${ENV}-rds-monitoring"

# ============================================================
# 4. ECS cluster
# ============================================================

echo "==> [4/6] Resolving ECS cluster resource IDs from AWS..."

ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --names "routebox-${ENV}-alb" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "    alb: $ALB_ARN"

HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text)
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)

SHIPMENTS_TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --names "rbx-${ENV}-shipments" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
ROUTEOPT_TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --names "rbx-${ENV}-routeopt" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
TRACKING_TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --names "rbx-${ENV}-tracking" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
PORTAL_TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --names "rbx-${ENV}-portal" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
OPSCON_TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
  --names "rbx-${ENV}-opscon" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

SHIPMENTS_RULE_ARN=$(aws elbv2 describe-rules --region "$REGION" \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[?Priority==`10`].RuleArn | [0]' --output text)
ROUTEOPT_RULE_ARN=$(aws elbv2 describe-rules --region "$REGION" \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[?Priority==`20`].RuleArn | [0]' --output text)
TRACKING_RULE_ARN=$(aws elbv2 describe-rules --region "$REGION" \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[?Priority==`30`].RuleArn | [0]' --output text)
OPSCON_RULE_ARN=$(aws elbv2 describe-rules --region "$REGION" \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[?Priority==`40`].RuleArn | [0]' --output text)
PORTAL_RULE_ARN=$(aws elbv2 describe-rules --region "$REGION" \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[?Priority==`50`].RuleArn | [0]' --output text)

echo "==> [4/6] Importing ECS cluster resources..."

TF 'module.ecs_cluster.aws_ecs_cluster.main'                      "routebox-${ENV}"
TF 'module.ecs_cluster.aws_cloudwatch_log_group.ecs'              "/routebox/${ENV}/ecs"
TF 'module.ecs_cluster.aws_lb.main'                               "$ALB_ARN"
TF 'module.ecs_cluster.aws_lb_target_group.shipments_api'         "$SHIPMENTS_TG_ARN"
TF 'module.ecs_cluster.aws_lb_target_group.route_optimizer'       "$ROUTEOPT_TG_ARN"
TF 'module.ecs_cluster.aws_lb_target_group.tracking_events'       "$TRACKING_TG_ARN"
TF 'module.ecs_cluster.aws_lb_target_group.customer_portal'       "$PORTAL_TG_ARN"
TF 'module.ecs_cluster.aws_lb_target_group.ops_console'           "$OPSCON_TG_ARN"
TF 'module.ecs_cluster.aws_lb_listener.http'                      "$HTTP_LISTENER_ARN"
TF 'module.ecs_cluster.aws_lb_listener.https'                     "$HTTPS_LISTENER_ARN"
TF 'module.ecs_cluster.aws_lb_listener_rule.shipments_api'        "$SHIPMENTS_RULE_ARN"
TF 'module.ecs_cluster.aws_lb_listener_rule.route_optimizer'      "$ROUTEOPT_RULE_ARN"
TF 'module.ecs_cluster.aws_lb_listener_rule.tracking_events'      "$TRACKING_RULE_ARN"
TF 'module.ecs_cluster.aws_lb_listener_rule.ops_console'          "$OPSCON_RULE_ARN"
TF 'module.ecs_cluster.aws_lb_listener_rule.customer_portal'      "$PORTAL_RULE_ARN"

# ============================================================
# 5. Secrets bootstrap
# ============================================================

echo "==> [5/6] Resolving KMS and Secrets Manager IDs from AWS..."

KMS_KEY_ID=$(aws kms describe-key --region "$REGION" \
  --key-id "alias/routebox-${ENV}-app-secrets" \
  --query 'KeyMetadata.KeyId' --output text)
echo "    kms key: $KMS_KEY_ID"

resolve_secret() {
  local secret_name="$1"
  aws secretsmanager get-secret-value --region "$REGION" \
    --secret-id "$secret_name" \
    --query '[ARN, VersionId]' --output text
}

read -r DB_URL_ARN       DB_URL_VER       <<< "$(resolve_secret "routebox/${ENV}/DATABASE_URL")"
read -r IAPI_TOKEN_ARN   IAPI_TOKEN_VER   <<< "$(resolve_secret "routebox/${ENV}/INTERNAL_API_TOKEN")"
read -r JWT_ARN          JWT_VER          <<< "$(resolve_secret "routebox/${ENV}/JWT_SIGNING_KEY")"
read -r CARRIER_ARN      CARRIER_VER      <<< "$(resolve_secret "routebox/${ENV}/CARRIER_WEBHOOK_SIGNING_KEY")"
read -r TE_KEY_ID_ARN    TE_KEY_ID_VER    <<< "$(resolve_secret "routebox/${ENV}/tracking-events/AWS_ACCESS_KEY_ID")"
read -r TE_SECRET_ARN    TE_SECRET_VER    <<< "$(resolve_secret "routebox/${ENV}/tracking-events/AWS_SECRET_ACCESS_KEY")"
read -r SMTP_ARN         SMTP_VER         <<< "$(resolve_secret "routebox/${ENV}/SMTP_PASSWORD")"
echo "    secrets resolved (7)"

echo "==> [5/6] Importing secrets bootstrap resources..."

TF 'module.secrets_bootstrap.aws_kms_key.app_secrets'   "$KMS_KEY_ID"
TF 'module.secrets_bootstrap.aws_kms_alias.app_secrets' "alias/routebox-${ENV}-app-secrets"

TF 'module.secrets_bootstrap.aws_secretsmanager_secret.database_url'            "$DB_URL_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.database_url'    "${DB_URL_ARN}|${DB_URL_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.internal_api_token'            "$IAPI_TOKEN_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.internal_api_token'    "${IAPI_TOKEN_ARN}|${IAPI_TOKEN_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.jwt_signing_key'            "$JWT_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.jwt_signing_key'    "${JWT_ARN}|${JWT_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.carrier_webhook_signing_key'            "$CARRIER_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.carrier_webhook_signing_key'    "${CARRIER_ARN}|${CARRIER_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.tracking_events_access_key_id'            "$TE_KEY_ID_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.tracking_events_access_key_id'    "${TE_KEY_ID_ARN}|${TE_KEY_ID_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.tracking_events_secret_access_key'            "$TE_SECRET_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.tracking_events_secret_access_key'    "${TE_SECRET_ARN}|${TE_SECRET_VER}"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret.smtp_password'            "$SMTP_ARN"
TF 'module.secrets_bootstrap.aws_secretsmanager_secret_version.smtp_password'    "${SMTP_ARN}|${SMTP_VER}"

# ============================================================
# 6. ECR (prod only)
# ============================================================

echo "==> [6/6] Importing ECR repositories..."

# ECR repos are global (not per-env). Import by repository name.
TF 'module.ecr.aws_ecr_repository.shipments_api'   "routebox-shipments-api"
TF 'module.ecr.aws_ecr_repository.route_optimizer' "routebox-route-optimizer"
TF 'module.ecr.aws_ecr_repository.tracking_events' "routebox-tracking-events"
TF 'module.ecr.aws_ecr_repository.customer_portal' "routebox-customer-portal"
TF 'module.ecr.aws_ecr_repository.ops_console'     "routebox-ops-console"

# ECR lifecycle policies import as <repository_name>.
TF 'module.ecr.aws_ecr_lifecycle_policy.shipments_api'   "routebox-shipments-api"
TF 'module.ecr.aws_ecr_lifecycle_policy.route_optimizer' "routebox-route-optimizer"
TF 'module.ecr.aws_ecr_lifecycle_policy.tracking_events' "routebox-tracking-events"
TF 'module.ecr.aws_ecr_lifecycle_policy.customer_portal' "routebox-customer-portal"
TF 'module.ecr.aws_ecr_lifecycle_policy.ops_console'     "routebox-ops-console"

echo ""
echo "==> All imports complete (6/6 modules)."
echo "    Next: terraform plan -var-file=prod.tfvars"
echo "    Expected diffs: ManagedBy tag (cloudformation → terraform), IAM policy drift."
echo "    RDS max_connections=400 is captured in prod.tfvars and will reconcile on apply."
