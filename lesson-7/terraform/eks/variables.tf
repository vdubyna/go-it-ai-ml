variable "aws_profile" {
  description = "AWS profile для створення EKS."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region для EKS."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Назва EKS-кластера."
  type        = string
  default     = "goit-mlops-eks"
}

variable "cluster_version" {
  description = "Версія Kubernetes для EKS. null означає AWS default version."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR для VPC кластера."
  type        = string
  default     = "10.42.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types для managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Тип capacity для node group: ON_DEMAND або SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type має бути ON_DEMAND або SPOT."
  }
}

variable "node_desired_size" {
  description = "Бажана кількість worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Мінімальна кількість worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Максимальна кількість worker nodes."
  type        = number
  default     = 3
}

