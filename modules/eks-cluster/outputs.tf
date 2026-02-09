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

# AWS Load Balancer Controller에 부여할 IAM Role ARN (Helm 차트 설치 시 사용)
output "lb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.lb_role.iam_role_arn
}
