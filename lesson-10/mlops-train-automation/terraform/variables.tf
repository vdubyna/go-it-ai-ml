variable "aws_profile" {
  description = "AWS profile для локального запуску Terraform."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region для Lambda та Step Functions."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Базова назва ресурсів AWS."
  type        = string
  default     = "mlops-train-automation"
}

variable "environment" {
  description = "Назва середовища для тегів."
  type        = string
  default     = "lesson-10"
}

variable "lambda_runtime" {
  description = "Python runtime для Lambda-функцій."
  type        = string
  default     = "python3.11"
}
