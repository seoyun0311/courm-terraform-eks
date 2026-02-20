# environments/prod/outputs.tf

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 제어 플레인 접속 URL (kubectl용)"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS 인증서 데이터"
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "lbc_iam_role_arn" {
  description = "AWS Load Balancer Controller IAM Role ARN"
  value       = module.lb_role.iam_role_arn
}

output "jenkins_url" {
  description = "젠킨스 접속 URL"
  value       = "http://${module.jenkins.public_ip}:8080"
}

# ==============================================================================
# Karpenter Outputs (for courm-bootstrap configuration)
# ==============================================================================

output "karpenter_controller_role_arn" {
  description = "Karpenter Controller IAM Role ARN (annotate ServiceAccount)"
  value       = module.eks_cluster.karpenter_controller_role_arn
}

output "karpenter_node_role_name" {
  description = "Karpenter Node IAM Role Name (use in EC2NodeClass .spec.role)"
  value       = module.eks_cluster.karpenter_node_role_name
}

output "karpenter_node_instance_profile_name" {
  description = "Karpenter Node Instance Profile Name"
  value       = module.eks_cluster.karpenter_node_instance_profile_name
}

output "karpenter_queue_name" {
  description = "SQS Queue Name for Spot Interruption Handling"
  value       = module.eks_cluster.karpenter_queue_name
}


output "rds_endpoints" {
  description = "DB 접속 주소"
  value = {
    product_master = module.rds_product.rds_endpoint
    order_master   = module.rds_order.rds_endpoint
  }
}

output "redis_endpoint" {
  description = "Redis 엔드포인트"
  value       = module.elasticache_redis.primary_endpoint
}

