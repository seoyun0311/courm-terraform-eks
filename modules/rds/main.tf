# modules/rds/main.tf

# 0. 비밀번호 자동 생성 (사용자가 직접 입력하지 않은 경우에만 생성)
resource "random_password" "password" {
  count            = var.password == null ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  # 입력받은 password가 있으면 그것을 쓰고, 없으면 생성된 난수를 사용
  db_password = var.password != null ? var.password : random_password.password[0].result
}

# 1. AWS Secrets Manager에 자격 증명 저장 (금고 생성)
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "rds/${var.identifier}/credentials"
  description = "Credentials for RDS instance ${var.identifier}"
  
  # 실습 편의를 위해 즉시 삭제 허용 (운영 환경에선 recovery_window_in_days 설정 권장)
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name        = "rds-secret-${var.identifier}"
    Environment = var.environment
  })
}

# 2. 금고 내용물 채우기 (JSON 형식으로 저장)
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.username
    password = local.db_password
    engine   = var.engine
    host     = aws_db_instance.master.address
    port     = var.port
    db_name  = var.db_name
  })
}

# 3. DB 서브넷 그룹
resource "aws_db_subnet_group" "this" {
  name        = "${var.identifier}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for ${var.identifier}"

  tags = merge(var.tags, {
    Name        = "${var.identifier}-subnet-group"
    Environment = var.environment
  })
}

# 4. RDS 파라미터 그룹
resource "aws_db_parameter_group" "this" {
  name   = "${var.identifier}-params"
  family = "postgres15"

  tags = merge(var.tags, {
    Name        = "${var.identifier}-params"
    Environment = var.environment
  })
}

# 5. RDS Master 인스턴스
resource "aws_db_instance" "master" {
  identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  password = local.db_password # 로컬 변수에 확정된 비밀번호 사용
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window

  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = true

  parameter_group_name = aws_db_parameter_group.this.name

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  performance_insights_enabled = var.performance_insights_enabled

  tags = merge(var.tags, {
    Name        = var.identifier
    Environment = var.environment
    Role        = "master"
  })
}

# 6. Read Replica (조건부 생성)
resource "aws_db_instance" "replica" {
  count = var.create_read_replica ? 1 : 0

  identifier = "${var.identifier}-replica"
  replicate_source_db = aws_db_instance.master.identifier
  instance_class = var.replica_instance_class

  storage_type      = "gp3"
  storage_encrypted = var.storage_encrypted
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible
  multi_az = false
  backup_retention_period = 0

  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = true
  parameter_group_name = aws_db_parameter_group.this.name

  deletion_protection = var.deletion_protection
  skip_final_snapshot = true

  performance_insights_enabled = var.performance_insights_enabled

  tags = merge(var.tags, {
    Name        = "${var.identifier}-replica"
    Environment = var.environment
    Role        = "replica"
  })
}