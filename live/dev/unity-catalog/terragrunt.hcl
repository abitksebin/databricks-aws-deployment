# Unit 3 of 4: Unity Catalog metastore, S3 storage, IAM role and workspace
# assignment. The identity applying this unit must be a Databricks account admin.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/databricks-unity-catalog"
}

dependency "workspace" {
  config_path = "../workspace"

  mock_outputs = {
    workspace_id = "0000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  region                = local.env.region
  prefix                = local.env.prefix
  tags                  = local.env.tags
  databricks_account_id = local.env.databricks_account_id

  workspace_id = dependency.workspace.outputs.workspace_id

  # Databricks allows ONE metastore per region per account. If one already
  # exists (accounts created after late 2023 may get one automatically), put its
  # ID here and this unit only assigns the workspace to it.
  existing_metastore_id = ""

  # Keep false outside throwaway environments: it protects the metastore and its
  # bucket from `terragrunt destroy` while they still contain data.
  force_destroy = false
}
