variable "region" {
  description = "AWS region of the workspace. Must match the region of the VPC."
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
  description = "Databricks account ID (a UUID, shown in the account console). Supplied via the DATABRICKS_ACCOUNT_ID environment variable in this repo; never commit it."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.databricks_account_id))
    error_message = "databricks_account_id must be a UUID. Export DATABRICKS_ACCOUNT_ID before running Terragrunt."
  }
}

# --- Inputs from the network module ------------------------------------------

variable "vpc_id" {
  description = "ID of the customer-managed VPC."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for cluster nodes. Databricks requires at least two, in different AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least two subnets in different availability zones."
  }
}

variable "security_group_id" {
  description = "Security group ID for cluster nodes."
  type        = string
}

# --- Optional overrides --------------------------------------------------------

variable "root_bucket_name" {
  description = "Name of the workspace root S3 bucket. Defaults to <prefix>-root-<aws account id>, which is globally unique per AWS account."
  type        = string
  default     = null
}

variable "workspace_name" {
  description = "Display name of the workspace. Defaults to the prefix."
  type        = string
  default     = null
}

variable "deployment_name" {
  description = "Optional custom subdomain (<deployment_name>.cloud.databricks.com). Only available on some account types; leave null to use a generated URL."
  type        = string
  default     = null
}
