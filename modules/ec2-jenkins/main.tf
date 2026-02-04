resource "aws_instance" "jenkins" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id     = var.subnet_id

  # SSH 접속용 키 페어
  key_name      = var.key_name

  # 보안 그룹
  vpc_security_group_ids = var.security_group_ids

  tags = {
    Name = var.name
    Service = "jenkins"
  }
}
