# -----------------------------------------------------------------------------
# Environment settings for "dev". Edit the values marked CHANGE ME.
# To add another environment, copy live/dev to live/<env> and edit this file.
# -----------------------------------------------------------------------------

locals {
  # AWS region for every resource. The Databricks workspace, VPC and Unity
  # Catalog metastore must all be in the same region.
  region = "eu-west-2"

  # Short prefix for resource names (lowercase letters, digits, hyphens; 3-20
  # characters).
  prefix = "dbx-dev"

  # Remote state backend. CHANGE ME: S3 bucket names are globally unique.
  # Create the bucket and lock table with scripts/bootstrap-state.sh.
  state_bucket     = "change-me-tfstate-dbx-dev"
  state_lock_table = "tfstate-lock-dbx-dev"

  # Databricks account ID (a UUID from the account console). Read from the
  # environment so it is never committed:
  #   export DATABRICKS_ACCOUNT_ID=<your-account-id>
  # The empty default lets units that do not need it (network) still plan.
  databricks_account_id = get_env("DATABRICKS_ACCOUNT_ID", "")

  # Applied to every AWS resource, and to cluster nodes as custom tags.
  tags = {
    Project     = "databricks-aws-deployment"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
