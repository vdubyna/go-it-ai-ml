locals {
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    Lesson      = "lesson-5"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "./vpc"

  aws_profile             = var.aws_profile
  aws_region              = var.aws_region
  project_name            = var.project_name
  environment             = var.environment
  name                    = "${var.project_name}-${var.environment}-vpc"
  cluster_name            = var.cluster_name
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = var.availability_zone_count
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  tags                    = local.default_tags
}

module "eks" {
  source = "./eks"

  aws_profile                   = var.aws_profile
  aws_region                    = var.aws_region
  project_name                  = var.project_name
  environment                   = var.environment
  cluster_name                  = var.cluster_name
  cluster_version               = var.cluster_version
  use_remote_state              = false
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = module.vpc.public_subnets
  private_subnet_ids            = module.vpc.private_subnets
  node_subnet_type              = var.node_subnet_type
  node_capacity_type            = var.node_capacity_type
  cpu_node_instance_types       = var.cpu_node_instance_types
  cpu_node_min_size             = var.cpu_node_min_size
  cpu_node_max_size             = var.cpu_node_max_size
  cpu_node_desired_size         = var.cpu_node_desired_size
  gpu_node_instance_types       = var.gpu_node_instance_types
  gpu_node_min_size             = var.gpu_node_min_size
  gpu_node_max_size             = var.gpu_node_max_size
  gpu_node_desired_size         = var.gpu_node_desired_size
  node_disk_size                = var.node_disk_size
  cluster_endpoint_public_cidrs = var.cluster_endpoint_public_cidrs
  tags                          = local.default_tags
}
