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
  default     = "1.31" # 기본값 설정
}

variable "node_group_name" {
  description = "EKS 워커 노드 그룹의 식별자"
  default     = "worker-node"
}

variable "jenkins_iam_role_arn" {
  description = "IAM Role ARN of Jenkins"
  type        = string
}

variable "ci_subnet_ids" {
  description = "Jenkins Agent가 배치될 서브넷 ID 리스트 (단일 AZ)"
  type        = list(string)
}
