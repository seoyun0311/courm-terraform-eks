# ==============================================================================
# AWS EKS Cluster (Control Plane + Data Plane)
# ==============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  # 클러스터 생성자에게 관리자 권한 자동 부여
  enable_cluster_creator_admin_permissions = true

  # 인증 모드 설정: API와 ConfigMap을 병행 사용
  authentication_mode = "API_AND_CONFIG_MAP"

  # IAM 사용자 액세스 항목 설정
  access_entries = {
    root = {
      principal_arn = "arn:aws:iam::900808296075:root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    user = {
      principal_arn = "arn:aws:iam::900808296075:user/user"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    courm-jjm = {
      principal_arn = "arn:aws:iam::900808296075:user/courm-jjm"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    goorm_infra = {
      principal_arn = "arn:aws:iam::900808296075:user/goorm-infra"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    jenkins = {
      principal_arn = var.jenkins_iam_role_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Compute (Data Plane)
  # ----------------------------------------------------------------------------
  eks_managed_node_groups = {
    worker_node = {
      node_group_name = var.node_group_name
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
        Name        = "${var.cluster_name}-worker"
        Environment = var.environment
        Project     = var.project
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEBSCSIDriverPolicy      = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }

    # 5. CI-Build (Jenkins Agent)
    ci_build = {
      name           = "courm-ng-ci"
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      min_size       = 1
      max_size       = 5
      desired_size   = 1

      subnet_ids     = var.ci_subnet_ids

      labels = {
        role = "ci"
      }

      # Jenkins 파드 설정에 'tolerations'를 넣어줘야 들어올 수 있음
      taints = [
        {
          key    = "role"
          value  = "ci"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEBSCSIDriverPolicy      = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  cluster_addons = {
    coredns = {}
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}
    aws-ebs-csi-driver = {}
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
  attach_load_balancer_controller_policy = true

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

