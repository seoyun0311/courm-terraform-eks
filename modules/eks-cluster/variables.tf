variable "project" {
  description = "프로젝트 이름 (예: courm)"
  type        = string
  default     = "courm"
}

variable "environment" {
  description = "배포 환경 (예: prod, dev)"
  type        = string
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "vpc_id" {
  description = "EKS 클러스터가 생성될 VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "EKS 워커 노드와 컨트롤 플레인이 배치될 서브넷 ID 목록"
  type        = list(string)
}

variable "cluster_version" {
  description = "쿠버네티스 버전"
  type        = string
  default     = "1.30" # 기본값 설정
}
