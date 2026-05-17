output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert. Drop into a kubeconfig with `aws eks update-kubeconfig` rather than wiring this by hand."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL. Use this when wiring IRSA roles for workloads outside this module."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group. Allows control-plane ↔ node traffic."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group attached to the managed node group's instances. With no launch template and no remote_access set, EKS reuses the cluster's primary SG for nodes — that's the same value as cluster_security_group_id and is what nodes actually carry. Re-exported under this name for callers that want it explicitly."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA. Bind workload service accounts to IAM roles by trusting this ARN."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "kms_key_arn" {
  description = "KMS key used for envelope encryption of K8s secrets."
  value       = aws_kms_key.eks_secrets.arn
}

output "kms_key_alias" {
  description = "Alias name for the K8s secrets KMS key."
  value       = aws_kms_alias.eks_secrets.name
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for the cluster autoscaler Helm chart. Pass as serviceAccount.annotations.eks.amazonaws.com/role-arn."
  value       = aws_iam_role.cluster_autoscaler.arn
}
