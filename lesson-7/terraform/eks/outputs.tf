output "cluster_name" {
  description = "Назва EKS-кластера. Її читає terraform/argocd через remote state."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint EKS API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Фактична Kubernetes version EKS-кластера."
  value       = aws_eks_cluster.this.version
}

output "aws_region" {
  description = "AWS region EKS-кластера."
  value       = var.aws_region
}

output "configure_kubectl" {
  description = "Команда для перемикання kubectl на створений EKS-кластер."
  value       = "aws eks update-kubeconfig --profile ${var.aws_profile} --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

