output "ecr_urls" {
  description = "생성된 ECR 레포지토리 URL 목록"
  value       = {for name, repo in aws_ecr_repository.microservices : name => repo.repository_url}
}
