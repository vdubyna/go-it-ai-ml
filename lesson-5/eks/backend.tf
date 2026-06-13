terraform {
  backend "s3" {
    bucket  = "goit-mlops-terraform-601535178731"
    key     = "lesson-5/eks/terraform.tfstate"
    region  = "us-east-1"
    profile = "vdubyna"
    encrypt = true
  }
}
