variable "region" {
  description = "AWS region. Databricks allows one metastore per region per account."
  type        = string
}

variable "prefix" {
  description = "Short name prefix applied to every resource, e.g. dbx-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.prefix))
    error_message = "prefix must be 3-20 characters: lowercase letters, digits and hyphens only."
  }
}

variable "tags" {
  description = "Tags applied to all AWS resources."
  type        = map(string)
  default     = {}
}

variable "databricks_account_id" {
  description = "Databricks account ID (a UUID). Supplied via the DATABRICKS_ACCOUNT_ID environment variable in this repo; never commit it."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.databricks_account_id))
    error_message = "databricks_account_id must be a UUID. Export DATABRICKS_ACCOUNT_ID before running Terragrunt."
  }
}

variable "workspace_id" {
  description = "ID of the workspace to assign the metastore to (output of the databricks-workspace module)."
  type        = string
}

variable "existing_metastore_id" {
  description = <<-EOT
    ID of a metastore that already exists in this region. When set, nothing is
    created except the workspace assignment. Leave empty to create a new
    metastore, its S3 bucket and its IAM role.

    Check the account console first: accounts created after late 2023 may
    already have a regional metastore created automatically with the first
    workspace.
  EOT
  type        = string
  default     = ""
}

variable "metastore_name" {
  description = "Metastore name. Defaults to <prefix>-<region>-metastore."
  type        = string
  default     = null
}

variable "metastore_bucket_name" {
  description = "Name of the metastore root S3 bucket. Defaults to <prefix>-uc-<aws account id>, which is globally unique per AWS account."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = <<-EOT
    Allow `destroy` to delete the metastore and its S3 bucket even if they
    contain data or catalogs. Keep false outside throwaway environments.
  EOT
  type        = bool
  default     = false
}
