# 테라폼 설정 및 AWS Provider 설정
terraform {
  required_version = ">= 1.9.0" # 최소 테라폼 버전 설정

  required_providers {
    # 1. AWS 프로바이더
    aws = {
      source = "hashicorp/aws" # AWS 프로바이더의 소스 지정
      version = ">= 5.80.0" # 5.80 버전 이상의 AWS 프로바이더 사용
    }

    # 2. Helm 프로바이더
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9, < 3.0.0"
    }

  }
}
