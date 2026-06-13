variable "aws_profile" {
  description = "AWS CLI profile for Terraform operations."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region for VPC and EKS resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in AWS resource tags and names."
  type        = string
  default     = "goit-mlops"
}

variable "environment" {
  description = "Environment label used in AWS tags."
  type        = string
  default     = "lesson-5"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "goit-mlops-lesson-5-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS. null means the current AWS default supported by the module."
  type        = string
  default     = null
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
  description = "Create NAT Gateway for private node subnets. This is disabled by default to avoid extra lab costs."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT Gateway when NAT is enabled."
  type        = bool
  default     = true
}

variable "node_subnet_type" {
  description = "Subnet type for EKS worker nodes: public for a cheaper lab setup, private for a production-like setup with NAT."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.node_subnet_type)
    error_message = "node_subnet_type must be public or private."
  }
}

variable "node_capacity_type" {
  description = "Capacity type for both managed node groups."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "cpu_node_instance_types" {
  description = "Instance types for the CPU node group."
  type        = list(string)
  default     = ["t3.micro"]
}

variable "cpu_node_min_size" {
  description = "Minimum size of the CPU node group."
  type        = number
  default     = 1
}

variable "cpu_node_max_size" {
  description = "Maximum size of the CPU node group."
  type        = number
  default     = 2
}

variable "cpu_node_desired_size" {
  description = "Desired size of the CPU node group."
  type        = number
  default     = 1
}

variable "gpu_node_instance_types" {
  description = "Instance types for the GPU-oriented node group. Defaults to t3.micro for Free Tier-friendly homework checks."
  type        = list(string)
  default     = ["t3.micro"]
}

variable "gpu_node_min_size" {
  description = "Minimum size of the GPU-oriented node group."
  type        = number
  default     = 1
}

variable "gpu_node_max_size" {
  description = "Maximum size of the GPU-oriented node group."
  type        = number
  default     = 2
}

variable "gpu_node_desired_size" {
  description = "Desired size of the GPU-oriented node group."
  type        = number
  default     = 1
}

variable "node_disk_size" {
  description = "Root volume size in GiB for EKS managed node groups."
  type        = number
  default     = 20
}

variable "cluster_endpoint_public_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
