# environments/prod/providers.tf

# 1. AWS 프로바이더 설정
provider "aws" {
  region = "ap-northeast-2"
  # profile = "aws_profile" # 필요시 주석 해제
}

# 2. Helm 프로바이더 설정
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
      command     = "aws"
    }
  }
}
