output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

# RDS, Redis 등 외부 리소스에서 EKS 파드의 접근을 허용하기 위한 보안 그룹 ID
output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# Control Plane 보안 그룹 (필요 시 사용)
output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enable_irsa = true"
  value       = module.eks.oidc_provider_arn
}

/* AWS Load Balancer Controller에 부여할 IAM Role ARN (Helm 차트 설치 시 사용)
output "lb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.lb_role.iam_role_arn
}
*/

# ==============================================================================
# Karpenter Outputs (for courm-bootstrap configuration)
# ==============================================================================

output "karpenter_controller_role_arn" {
  description = "IAM Role ARN for Karpenter Controller (annotate ServiceAccount with this)"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_role_name" {
  description = "IAM Role Name for Karpenter Nodes (use in EC2NodeClass)"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_node_instance_profile_name" {
  description = "Instance Profile Name for Karpenter Nodes"
  value       = module.karpenter.instance_profile_name
}

output "karpenter_queue_name" {
  description = "SQS Queue Name for Spot Interruption Handling"
  value       = module.karpenter.queue_name
}
