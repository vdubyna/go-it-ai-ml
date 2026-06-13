output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "Public subnet IDs for load balancers and optional lab worker nodes."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs for production-like EKS worker nodes."
  value       = module.vpc.private_subnets
}

output "azs" {
  description = "Availability zones used by the VPC."
  value       = local.azs
}

output "aws_region" {
  description = "AWS region used by this stack."
  value       = var.aws_region
}
