environment = "prod"
cost_center = "platform-prod"

vpc_cidr = "10.30.0.0/16"

public_subnet_cidrs = [
  "10.30.0.0/22",
  "10.30.4.0/22",
  "10.30.8.0/22",
]

private_subnet_cidrs = [
  "10.30.16.0/20",
  "10.30.32.0/20",
  "10.30.48.0/20",
]

enable_nat_gateway = true # prod has NAT — private subnets need egress

# ------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------

eks_kubernetes_version           = "1.35"
eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]
eks_node_instance_types          = ["t3.large"]
eks_node_capacity_type           = "ON_DEMAND"
eks_node_disk_size_gb            = 50
eks_node_min_size                = 2
eks_node_desired_size            = 3
eks_node_max_size                = 10

eks_cluster_admin_role_arns = [
  "arn:aws:iam::834786370659:role/aws-reserved/sso.amazonaws.com/us-east-2/AWSReservedSSO_Administrator_26e5753d72bb56b0",
]
