provider "aws" {
  region = "ap-northeast-2"
}

# 1. ECR 레포지토리 생성
resource "aws_ecr_repository" "microservices" {
  for_each             = toset(var.repository_names)
  
  name                 = "${each.value}"
  image_tag_mutability = "MUTABLE" # Blue/Green 배포 시 태그 덮어쓰기(latest) 등을 위해 개발 단계에선 MUTABLE 권장

  # 이미지 스캔 (보안)
  image_scanning_configuration {
    scan_on_push = true
  }

  # 암호화 설정 (KMS)
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Environment = "global"
    Service     = each.value
  }
}

# 2. 수명 주기 정책 (비용 절감)
# 이미지가 계속 쌓이면 스토리지 비용이 발생하므로, 최근 30개만 남기고 삭제
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each   = aws_ecr_repository.microservices # 생성된 모든 리포지토리에 적용
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
}
