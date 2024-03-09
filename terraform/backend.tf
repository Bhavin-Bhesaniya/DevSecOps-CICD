terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.39.0"
    }
  }

  backend "s3" {
    bucket         = "devsecops-cicd-bucket"
    key            = "state/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-lockfile-table"
  }
}
