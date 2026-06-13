locals {
  vpc_id = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.vpc_id : var.vpc_id

  public_subnet_ids = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.public_subnets : var.public_subnet_ids

  private_subnet_ids = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.private_subnets : var.private_subnet_ids

  node_subnet_ids = var.node_subnet_type == "private" ? local.private_subnet_ids : local.public_subnet_ids

  control_plane_subnet_ids = length(local.private_subnet_ids) > 0 ? local.private_subnet_ids : local.public_subnet_ids

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Lesson      = "lesson-5"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = local.vpc_id
  subnet_ids               = local.node_subnet_ids
  control_plane_subnet_ids = local.control_plane_subnet_ids

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_cidrs

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  cluster_addons = {
    coredns                  = {}
    "eks-pod-identity-agent" = {}
    "kube-proxy"             = {}
    "vpc-cni"                = {}
  }

  eks_managed_node_group_defaults = {
    capacity_type  = var.node_capacity_type
    instance_types = ["t3.micro"]
    disk_size      = var.node_disk_size
  }

  eks_managed_node_groups = {
    cpu = {
      name           = "${var.cluster_name}-cpu"
      instance_types = var.cpu_node_instance_types
      min_size       = var.cpu_node_min_size
      max_size       = var.cpu_node_max_size
      desired_size   = var.cpu_node_desired_size

      labels = {
        workload = "cpu"
        role     = "mlops-cpu"
      }

      tags = merge(local.common_tags, {
        NodeGroup = "cpu"
        Workload  = "cpu"
      })
    }

    gpu = {
      name           = "${var.cluster_name}-gpu"
      instance_types = var.gpu_node_instance_types
      min_size       = var.gpu_node_min_size
      max_size       = var.gpu_node_max_size
      desired_size   = var.gpu_node_desired_size

      labels = {
        workload    = "gpu"
        role        = "mlops-gpu"
        accelerator = "none"
      }

      tags = merge(local.common_tags, {
        NodeGroup = "gpu"
        Workload  = "gpu"
      })
    }
  }

  tags = local.common_tags
}
