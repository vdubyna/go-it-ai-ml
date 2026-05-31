variable "aws_profile" {
  description = "AWS profile для доступу до EKS і S3 remote state."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region, де розгорнутий EKS кластер."
  type        = string
  default     = "us-east-1"
}

variable "tf_state_bucket" {
  description = "S3 bucket з Terraform remote state існуючого EKS-кластера."
  type        = string
  default     = "goit-mlops-terraform-601535178731"
}

variable "eks_state_key" {
  description = "S3 key remote state існуючого EKS-кластера."
  type        = string
  default     = "eks/terraform.tfstate"
}

variable "argocd_namespace" {
  description = "Namespace для ArgoCD."
  type        = string
  default     = "infra-tools"
}

variable "argocd_chart_version" {
  description = "Версія Helm-чарту argo-cd."
  type        = string
  default     = "9.5.17"
}

variable "argocd_apps_chart_version" {
  description = "Версія Helm-чарту argocd-apps для bootstrap Application."
  type        = string
  default     = "2.0.5"
}

variable "app_repo_url" {
  description = "Public Git URL репозиторію, який читатиме ArgoCD."
  type        = string
  default     = "https://github.com/vdubyna/go-it-ai-ml.git"
}

variable "app_repo_branch" {
  description = "Git branch для синхронізації GitOps-репозиторію."
  type        = string
  default     = "lesson-7"
}

variable "app_repo_path" {
  description = "Path у GitOps-репозиторії, який читатиме root ArgoCD Application."
  type        = string
  default     = "lesson-7/goit-argo"
}
