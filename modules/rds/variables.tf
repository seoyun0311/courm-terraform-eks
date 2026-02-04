# modules/rds/variables.tf

variable "identifier" {
  description = "RDS 인스턴스 식별자"
  type        = string
}

variable "environment" {
  description = "환경 (prod, dev, staging)"
  type        = string
}

variable "engine" {
  description = "데이터베이스 엔진"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "데이터베이스 엔진 버전"
  type        = string
  default     = "15"
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "할당된 스토리지 (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "자동 확장 최대 스토리지 (GB)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "courm_admin"
}

variable "password" {
  description = "마스터 비밀번호 (입력하지 않으면 자동 생성됨)"
  type        = string
  sensitive   = true
  default     = null
}

variable "port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 5432
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "RDS 서브넷 ID 리스트"
  type        = list(string)
}

variable "security_group_ids" {
  description = "보안 그룹 ID 리스트"
  type        = list(string)
  default     = []
}

variable "multi_az" {
  description = "Multi-AZ 배포 여부"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "백업 보관 기간 (일)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "백업 윈도우 (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 윈도우 (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "deletion_protection" {
  description = "삭제 방지 활성화"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "삭제 시 최종 스냅샷 생략"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "스토리지 암호화 활성화"
  type        = bool
  default     = true
}

variable "create_read_replica" {
  description = "Read Replica 생성 여부"
  type        = bool
  default     = false
}

variable "replica_instance_class" {
  description = "Read Replica 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro"
}

variable "publicly_accessible" {
  description = "퍼블릭 접근 허용 여부"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = false
}

variable "tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}
