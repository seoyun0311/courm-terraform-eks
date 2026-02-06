# environments/prod/main.tf

locals {
  common_tags = {
    Project     = "courm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  image_tag = "latest"
}

# ==============================================================================
# 1. VPC & Network
# ==============================================================================
module "vpc" {
  source = "../../modules/vpc"

  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  azs            = var.azs
  public_subnets = var.public_subnets
  app_subnets    = var.app_subnets
  mq_subnets     = var.mq_subnets
  mgmt_subnets   = var.mgmt_subnets
  data_subnets   = var.data_subnets
}

# ==============================================================================
# 2. EKS Cluster
# ==============================================================================
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  project      = "courm"
  environment  = var.environment
  cluster_name = "courm-eks-${var.environment}"
  node_group_name = "courm-worker"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.app_subnet_ids
  jenkins_iam_role_arn = module.jenkins.iam_role_arn
  ci_subnet_ids = [module.vpc.app_subnet_ids[0]]
}

# ==============================================================================
# 3. Security Groups
# ==============================================================================

# (1) RDS Security Group
module "sg_rds" {
  source = "../../modules/security-groups"
  name   = "courm-sg-rds-${var.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port = 5432
      to_port   = 5432
      protocol  = "tcp"
      security_groups = [module.eks_cluster.node_security_group_id]
    }
  ]
}

# (2) Redis Security Group - EKS 노드 접근 허용으로 변경
module "sg_redis" {
  source = "../../modules/security-groups"
  name   = "courm-sg-redis-${var.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port = 6379
      to_port   = 6379
      protocol  = "tcp"
      security_groups = [module.eks_cluster.node_security_group_id]
    }
  ]
}

# (3) Kafka Security Group
module "sg_kafka" {
  source = "../../modules/security-groups"
  name   = "courm-sg-kafka-${var.environment}"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      from_port = 9092
      to_port   = 9092
      protocol  = "tcp"
      security_groups = [module.eks_cluster.node_security_group_id]
    },
    { from_port = 0,    to_port = 0,    protocol = "-1",  cidr_blocks = module.vpc.mq_subnet_cidrs }
  ]
  egress_rules = [{ from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }]
}

# (4) Jenkins Security Group
module "sg_jenkins" {
  source = "../../modules/security-groups"
  name   = "courm-sg-jenkins-${var.environment}"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 8080, to_port = 8080, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 22,   to_port = 22,   protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ]
  egress_rules = [{ from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }]
}

resource "aws_security_group_rule" "eks_cluster_ingress_jenkins" {
  description              = "Allow Jenkins to communicate with EKS API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"

  security_group_id        = module.eks_cluster.cluster_security_group_id

  source_security_group_id = module.sg_jenkins.security_group_id
}

resource "aws_security_group_rule" "jenkins_ingress_jnlp_from_nodes" {
  description              = "Allow JNLP agents in EKS to connect to Jenkins Master"
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"

  security_group_id        = module.sg_jenkins.security_group_id

  source_security_group_id = module.eks_cluster.node_security_group_id
}
# ==============================================================================
# 5. Data Stores & Tools
# ==============================================================================
module "rds_order" {
  source = "../../modules/rds"
  identifier         = "courm-rds-order-${var.environment}"
  environment        = var.environment
  db_name            = "courm_order"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.data_subnet_ids
  security_group_ids = [module.sg_rds.security_group_id]
  username           = var.db_username
  password           = var.db_password
  tags               = { Service = "order-payment-user" }
}

module "rds_product" {
  source = "../../modules/rds"
  identifier         = "courm-rds-product-${var.environment}"
  environment        = var.environment
  db_name            = "courm_product"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.data_subnet_ids
  security_group_ids = [module.sg_rds.security_group_id]
  username           = var.db_username
  password           = var.db_password
  create_read_replica = true
  tags               = { Service = "product-review" }
}

module "elasticache_redis" {
  source = "../../modules/elasticache"
  cluster_id         = "courm-redis-${var.environment}"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.data_subnet_ids
  security_group_ids = [module.sg_redis.security_group_id]
  tags               = { Service = "product-cache-cart-lock" }
}

module "kafka" {
  source = "../../modules/ec2-kafka"
  environment        = var.environment
  subnet_ids         = module.vpc.mq_subnet_ids
  security_group_ids = [module.sg_kafka.security_group_id]
  ami_id             = var.kafka_ami_id
  instance_type      = var.kafka_instance_type
  key_name           = var.key_pair_name
}

module "jenkins" {
  source = "../../modules/ec2-jenkins"
  name               = "courm-jenkins-${var.environment}"
  ami_id             = var.jenkins_ami_id
  instance_type      = var.jenkins_instance_type
  key_name           = var.key_pair_name
  subnet_id          = module.vpc.mgmt_subnet_ids[0]
  security_group_ids = [module.sg_jenkins.security_group_id]
}

# ==============================================================================
# 6. ECR Data Sources
# ==============================================================================
data "aws_ecr_repository" "user"    { name = "goorm-user" }
data "aws_ecr_repository" "product" { name = "goorm-product" }
data "aws_ecr_repository" "order"   { name = "goorm-order" }
data "aws_ecr_repository" "payment" { name = "goorm-payment" }
data "aws_ecr_repository" "cart"    { name = "goorm-cart" }

# ==============================================================================
# 7. GuardDuty
# ==============================================================================
resource "aws_guardduty_detector" "this" {
  enable = true
  tags   = { Name = "courm-guardduty-${var.environment}" }
}

# ==============================================================================
# 8. API Gateway
# ==============================================================================
# [주석 처리] ALB가 삭제되었으므로 주소 참조 불가능. 추후 Ingress 생성 후 연결 필요.
# module "api_gateway" {
#   source = "../../modules/api-gateway"
#   alb_dns_name = module.alb.alb_dns_name
# }
