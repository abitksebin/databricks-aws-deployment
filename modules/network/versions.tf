# Provider and Terraform version constraints for the network module.
# Version ranges (not exact pins) keep the module usable as the providers
# evolve; Terragrunt/Terraform lock files pin exact versions per environment.
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Tags applied to every taggable resource created by this module.
  default_tags {
    tags = var.tags
  }
}
