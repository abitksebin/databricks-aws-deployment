# -----------------------------------------------------------------------------
# Root Terragrunt configuration, included by every unit under live/.
#
# Responsibilities:
#   - Remote state: one S3 bucket with DynamoDB locking, one state file per unit.
#
# Provider configuration lives inside each module (see versions.tf), because the
# units use different providers: AWS only, AWS + account-level Databricks, or
# workspace-level Databricks only.
# -----------------------------------------------------------------------------

locals {
  # Environment settings (region, state bucket, tags). Resolved relative to the
  # unit that includes this file, so live/dev/env.hcl is picked up for units in
  # live/dev/*.
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

remote_state {
  backend = "s3"

  # Terragrunt writes backend.tf into each unit's working directory, so modules
  # do not declare a backend themselves.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = local.env.state_bucket

    # e.g. live/dev/network/terraform.tfstate
    key = "${path_relative_to_include()}/terraform.tfstate"

    region  = local.env.region
    encrypt = true

    # State locking. Create the table with scripts/bootstrap-state.sh.
    dynamodb_table = local.env.state_lock_table
  }
}
