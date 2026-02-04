# modules/rds/outputs.tf

output "rds_id" {
  description = "RDS 인스턴스 ID"
  value       = aws_db_instance.master.id
}

output "rds_endpoint" {
  description = "RDS 연결 엔드포인트"
  value       = aws_db_instance.master.endpoint
}

output "rds_address" {
  description = "RDS 주소"
  value       = aws_db_instance.master.address
}
output "replica_endpoint" {

  description = "Read Replica 연결 엔드포인트"

  value       = try(aws_db_instance.replica[0].endpoint, null)

}
output "replica_address" {

  description = "Read Replica 주소"

  value       = try(aws_db_instance.replica[0].address, null)

}

output "rds_port" {
  description = "RDS 포트"
  value       = aws_db_instance.master.port
}

output "rds_secret_arn" {
  description = "Secrets Manager에 저장된 자격 증명의 ARN"
  value       = aws_secretsmanager_secret.db_credentials.arn
}