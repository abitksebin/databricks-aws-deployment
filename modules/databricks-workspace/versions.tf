# Provider and Terraform version constraints for the workspace module.
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
    # Used only to pause briefly while new IAM resources propagate.
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

# Account-level Databricks provider. Workspaces, credentials, storage
# configurations and networks are all managed through the account console API,
# not through a workspace URL.
#
# Authentication is NOT configured here so that no secrets live in code. Export
# an OAuth machine-to-machine service principal before running Terraform:
#   DATABRICKS_CLIENT_ID, DATABRICKS_CLIENT_SECRET
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
