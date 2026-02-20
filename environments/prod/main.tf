# environments/prod/main.tf

locals {
  common_tags = {
    Project     = "courm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
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
# 2. Jenkins (Master on EC2)
# ==============================================================================
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
# 3. EKS Cluster
# ==============================================================================
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  project         = "courm"
  environment     = var.environment
  cluster_name    = "courm-eks-${var.environment}"
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.app_subnet_ids

  jenkins_iam_role_arn = module.jenkins.iam_role_arn
  ci_subnet_ids        = [module.vpc.app_subnet_ids[0]]
}

# ==============================================================================
# 4. Security Groups
# ==============================================================================

# (1) RDS Security Group
module "sg_rds" {
  source = "../../modules/security-groups"
  name   = "courm-sg-rds-${var.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [module.eks_cluster.node_security_group_id]
    }
  ]
}

# (2) Redis Security Group
module "sg_redis" {
  source = "../../modules/security-groups"
  name   = "courm-sg-redis-${var.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [module.eks_cluster.node_security_group_id]
    }
  ]
}

# (3) Jenkins Security Group (Master)
module "sg_jenkins" {
  source = "../../modules/security-groups"
  name   = "courm-sg-jenkins-${var.environment}"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [
    { from_port = 8080, to_port = 8080, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # Web UI
    { from_port = 22,   to_port = 22,   protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # SSH
    { from_port = 50000, to_port = 50000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] } # JNLP
  ]

  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

# Jenkins Master -> EKS Control Plane
resource "aws_security_group_rule" "eks_cluster_ingress_jenkins" {
  description              = "Allow Jenkins Master to communicate with EKS API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.cluster_security_group_id
  source_security_group_id = module.sg_jenkins.security_group_id
}

# EKS Agents (Pods) -> Jenkins Master
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

# ==============================================================================
# 6. ECR & Other Resources
# ==============================================================================
data "aws_ecr_repository" "repos" {
  for_each = toset(["goorm-user", "goorm-product", "goorm-order", "goorm-payment", "goorm-cart"])
  name     = each.key
}

resource "aws_guardduty_detector" "this" {
  enable = true
  tags   = { Name = "courm-guardduty-${var.environment}" }
}

# ==============================================================================
# 4-1. Istio / Admission Webhook 추가 규칙
# ==============================================================================

# EKS Control Plane (Master) -> EKS Nodes (Istiod Webhook)
resource "aws_security_group_rule" "eks_master_to_node_istio_webhook" {
  description              = "Allow EKS Control Plane to reach Istiod Webhook (15017)"
  type                     = "ingress"
  from_port                = 15017
  to_port                  = 15017
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.node_security_group_id
  source_security_group_id = module.eks_cluster.cluster_security_group_id
}

# 다른 툴(Karpenter, Metric Server 등)을 위해 노드의 443~9443도 열어주는 것
resource "aws_security_group_rule" "eks_master_to_node_general_webhooks" {
  description              = "Allow EKS Control Plane to communicate with Webhooks on Nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.node_security_group_id
  source_security_group_id = module.eks_cluster.cluster_security_group_id
}
