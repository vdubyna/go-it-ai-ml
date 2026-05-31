provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

