output "vpc_id" {
  description = "Created VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "Created EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "node_group_names" {
  description = "Managed node group names created by the EKS module."
  value       = module.eks.node_group_names
}

output "configure_kubectl" {
  description = "Command for adding the created EKS cluster to kubeconfig."
  value       = module.eks.configure_kubectl
}
