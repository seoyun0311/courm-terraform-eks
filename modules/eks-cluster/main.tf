# ==============================================================================
# Data Sources & Locals
# ==============================================================================
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  common_iam_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
}

# ==============================================================================
# AWS EKS Cluster (Control Plane + Data Plane)
# ==============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids           # Control Plane Subnets
  control_plane_subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true
  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  # ----------------------------------------------------------------------------
  # Access Entries (IAM User/Role Mapping)
  # ----------------------------------------------------------------------------
  access_entries = {
    # Root User
    root = {
      principal_arn = "arn:aws:iam::${local.account_id}:root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    # IAM User: user
    user = {
      principal_arn = "arn:aws:iam::${local.account_id}:user/user"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # IAM User: courm-jjm
    courm_jjm = {
      principal_arn = "arn:aws:iam::900808296075:user/courm-jjm"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    # IAM User: goorm-infra
    goorm_infra = {
      principal_arn = "arn:aws:iam::${local.account_id}:user/goorm-infra"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # IAM Role: Jenkins
    jenkins_role = {
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
  # Compute (Managed Node Groups) - 5 Groups
  # ----------------------------------------------------------------------------
  eks_managed_node_groups = {

    # 1. Management AZ a, c (ArgoCD, Istiod, Controllers)
    management = {
      name            = "${var.cluster_name}-ng-mgmt"
      use_name_prefix = false
      iam_role_name   = "${var.cluster_name}-ng-mgmt-role"
      subnet_ids      = var.subnet_ids # AZ a, c

      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "management"
      }

      iam_role_additional_policies = local.common_iam_policies
    }

    # 2. Monitoring AZ a, c (Prometheus, Grafana, Loki)
    monitoring = {
      name            = "${var.cluster_name}-ng-mon"
      use_name_prefix = false
      iam_role_name   = "${var.cluster_name}-ng-mon-role"
      subnet_ids      = var.subnet_ids # AZ a, c

      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "monitoring"
      }

      iam_role_additional_policies = local.common_iam_policies
    }

    # 3. Data-Store AZ a, c (Kafka Broker 3 nodes)
    data_store = {
      name            = "${var.cluster_name}-ng-data"
      use_name_prefix = false
      iam_role_name   = "${var.cluster_name}-ng-data-role"
      subnet_ids      = var.subnet_ids # AZ a, c

      min_size     = 3
      max_size     = 4
      desired_size = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50
            volume_type = "gp3"
            encrypted   = true
          }
        }
      }

      labels = {
        role = "data-store"
      }

      iam_role_additional_policies = local.common_iam_policies
    }

    # 4. Service-App AZ a, c (Service Pods, Istio Ingress)
    service_app = {
      name            = "${var.cluster_name}-ng-app"
      use_name_prefix = false
      iam_role_name   = "${var.cluster_name}-ng-app-role"
      subnet_ids      = var.subnet_ids # AZ a, c

      min_size     = 2
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "service-app"
      }

      iam_role_additional_policies = local.common_iam_policies
    }

    # 5. CI-Build AZ a (Jenkins Agents)
    ci_build = {
      name            = "courm-ng-ci"
      use_name_prefix = false
      iam_role_name   = "courm-ng-ci-role"
      subnet_ids      = var.ci_subnet_ids

      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      labels = {
        role = "ci"
      }

      taints = [
        {
          key    = "role"
          value  = "ci"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = local.common_iam_policies
    }
  }

  # Cluster Add-ons
  cluster_addons = {
    coredns = {}
    vpc-cni = {
      before_compute = true
    }
    kube-proxy         = {}
    aws-ebs-csi-driver = {}
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# Karpenter Module (Controller + Node IAM Roles, SQS, EventBridge)
# ==============================================================================
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # IRSA for Karpenter Controller
  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Karpenter Node IAM Role
  create_node_iam_role = true
  node_iam_role_name   = "${var.cluster_name}-karpenter-node"
  
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

