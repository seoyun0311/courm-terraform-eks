# ==============================================================================
# AWS EKS Cluster (Control Plane + Data Plane)
# ==============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # ----------------------------------------------------------------------------
  # Network Configuration
  # ----------------------------------------------------------------------------
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids       # 워커 노드용 Subnet (App Subnet)
  control_plane_subnet_ids = var.subnet_ids       # Control Plane용 Subnet

  # 외부(로컬 PC) 및 노드 간 통신 설정
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # ----------------------------------------------------------------------------
  # IAM & Authentication
  # ----------------------------------------------------------------------------
  # OIDC Provider 활성화
  enable_irsa = true

  # Terraform 실행 사용자에게 관리자 권한 부여
  enable_cluster_creator_admin_permissions = true

  # ----------------------------------------------------------------------------
  # Compute (Data Plane)
  # ----------------------------------------------------------------------------
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 5
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 30
            volume_type = "gp3"
            encrypted   = true
          }
        }
      }

      tags = {
        Environment = var.environment
        Project     = var.project
      }

      # SSM 접속 등을 위한 추가 정책
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Cluster Add-ons
  # ----------------------------------------------------------------------------
  cluster_addons = {
    coredns = { most_recent = true }
    vpc-cni = { most_recent = true }
    kube-proxy = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# AWS Load Balancer Controller IAM Role
# ==============================================================================

module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.0"

  role_name = "${var.cluster_name}-lb-controller"

  # AWS Load Balancer Controller에 필요한 정책 자동 연결
  attach_load_balancer_controller_policy = true

  # 위에서 만든 EKS 클러스터의 OIDC Provider와 연결
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}
