# Provider and Terraform version constraints for the Unity Catalog module.
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 7.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50, < 2.0"
    }
    # Used only to pause briefly while the new IAM role propagates.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# Account-level provider: metastores and workspace assignments are account
# resources. Auth comes from DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET.
# The identity must be a Databricks account admin.
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
