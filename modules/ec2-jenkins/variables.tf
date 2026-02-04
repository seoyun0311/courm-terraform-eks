variable "name" {
  description = "인스턴스 이름"
}

variable "ami_id" {
  description = "사용할 AMI ID"
}

variable "instance_type" {
  description = "인스턴스 타입"
}

variable "subnet_id" {
  description = "배포할 서브넷 ID"
}

variable "key_name" {
  description = "SSH 키페어 이름"
}

variable "security_group_ids" {
  description = "적용할 보안그룹 리스트"
}
