output "cluster_arn" {
  description = "The Amazon Resource Name of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API."
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  value       = module.eks.cluster_version
}

output "node_group_names" {
  description = "Managed node group names."
  value       = keys(module.eks.eks_managed_node_groups)
}

output "configure_kubectl" {
  description = "Command for adding the created EKS cluster to kubeconfig."
  value       = "aws eks update-kubeconfig --profile ${var.aws_profile} --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
