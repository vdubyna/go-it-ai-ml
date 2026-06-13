data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets = [
    for index, az in local.azs : cidrsubnet(var.vpc_cidr, 8, index)
  ]

  private_subnets = [
    for index, az in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 10)
  ]

  public_subnet_names = [
    for az in local.azs : "${var.name}-public-${az}"
  ]

  private_subnet_names = [
    for az in local.azs : "${var.name}-private-${az}"
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = local.common_tags
}
