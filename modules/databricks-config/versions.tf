# Provider and Terraform version constraints for the workspace-config module.
terraform {
  required_version = ">= 1.6"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.50, < 2.0"
    }
  }
}

# Workspace-level Databricks provider. This is why workspace configuration is a
# separate unit: the workspace URL only exists after the workspace is created.
#
# Authentication comes from the environment, using the same OAuth service
# principal as the account-level units:
#   DATABRICKS_CLIENT_ID, DATABRICKS_CLIENT_SECRET
# The service principal must be a workspace admin.
provider "databricks" {
  host = var.workspace_url
}
