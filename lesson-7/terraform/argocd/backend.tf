terraform {
  backend "s3" {
    bucket  = "goit-mlops-terraform-601535178731"
    key     = "argocd/terraform.tfstate"
    region  = "us-east-1"
    profile = "vdubyna"
  }
}
