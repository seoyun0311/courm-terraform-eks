# modules/ec2_jenkins/outputs.tf

output "instance_id" {
  description = "생성된 젠킨스 인스턴스의 ID"
  value       = aws_instance.jenkins.id
}

output "public_ip" {
  description = "젠킨스 접속용 Public IP"
  value       = aws_instance.jenkins.public_ip
}

output "private_ip" {
  description = "내부 통신용 Private IP"
  value       = aws_instance.jenkins.private_ip
}

output "availability_zone" {
  description = "실제로 배포된 가용영역"
  value       = aws_instance.jenkins.availability_zone
}
