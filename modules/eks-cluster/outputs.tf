# modules/eks-cluster/outputs.tf

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

# RDS, Redis 등에서 접근을 허용하기 위해 필요한 보안 그룹 ID
output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# 나중에 Helm/ArgoCD에 전달해야 할 Load Balancer Controller용 Role ARN
output "lb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.lb_role.iam_role_arn
}

output "node_group_arn" {
  value = module.eks.eks_managed_node_groups["worker_node"].node_group_arn
}
