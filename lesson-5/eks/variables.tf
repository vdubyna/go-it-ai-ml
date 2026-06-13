variable "aws_profile" {
  description = "AWS CLI profile for Terraform operations."
  type        = string
  default     = "vdubyna"
}

variable "aws_region" {
  description = "AWS region for EKS resources."
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

variable "use_remote_state" {
  description = "Read VPC outputs from S3 terraform_remote_state. Set to false only when this module is called from the root module."
  type        = bool
  default     = true
}

variable "remote_state_bucket" {
  description = "S3 bucket with Terraform remote states."
  type        = string
  default     = "goit-mlops-terraform-601535178731"
}

variable "remote_state_region" {
  description = "AWS region where the Terraform state bucket is located."
  type        = string
  default     = "us-east-1"
}

variable "vpc_state_key" {
  description = "S3 key of the VPC Terraform state file."
  type        = string
  default     = "lesson-5/vpc/terraform.tfstate"
}

variable "vpc_id" {
  description = "VPC ID. Used when use_remote_state is false."
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "Public subnet IDs. Used when use_remote_state is false."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs. Used when use_remote_state is false."
  type        = list(string)
  default     = []
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

variable "tags" {
  description = "Additional tags for all EKS resources."
  type        = map(string)
  default     = {}
}
