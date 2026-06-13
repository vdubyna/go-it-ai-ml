variable "aws_profile" {
  description = "AWS CLI profile for Terraform operations."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region for VPC resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in tags."
  type        = string
  default     = "goit-mlops"
}

variable "environment" {
  description = "Environment label used in tags."
  type        = string
  default     = "lesson-5"
}

variable "name" {
  description = "Name prefix for VPC resources."
  type        = string
  default     = "goit-mlops-lesson-5-vpc"
}

variable "cluster_name" {
  description = "EKS cluster name used in Kubernetes subnet tags."
  type        = string
  default     = "goit-mlops-lesson-5-eks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "availability_zone_count" {
  description = "How many availability zones to use."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway for private subnets."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway when NAT is enabled."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all VPC resources."
  type        = map(string)
  default     = {}
}
