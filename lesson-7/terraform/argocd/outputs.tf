output "argocd_namespace" {
  description = "Namespace, де встановлено ArgoCD."
  value       = var.argocd_namespace
}

output "argocd_server_port_forward" {
  description = "Команда для відкриття ArgoCD UI локально."
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:80"
}

output "argocd_initial_password_command" {
  description = "Команда для отримання початкового пароля admin."
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
}

output "gitops_repo_url" {
  description = "GitOps repo, який синхронізує ArgoCD."
  value       = var.app_repo_url
}

