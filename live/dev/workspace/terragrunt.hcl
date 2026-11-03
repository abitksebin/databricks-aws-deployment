# Unit 2 of 4: cross-account IAM role, root bucket and the Databricks workspace.
# Requires DATABRICKS_ACCOUNT_ID, DATABRICKS_CLIENT_ID and DATABRICKS_CLIENT_SECRET
# in the environment.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/databricks-workspace"
}

# Terragrunt applies the network unit first and passes its outputs in.
dependency "network" {
  config_path = "../network"

  # Placeholder values so init/validate/plan can run before the network exists.
  # They are never used for apply.
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000000", "subnet-11111111111111111"]
    security_group_id  = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  region                = local.env.region
  prefix                = local.env.prefix
  tags                  = local.env.tags
  databricks_account_id = local.env.databricks_account_id

  vpc_id            = dependency.network.outputs.vpc_id
  subnet_ids        = dependency.network.outputs.private_subnet_ids
  security_group_id = dependency.network.outputs.security_group_id

  # Optional: override generated names (bucket names must be globally unique).
  # root_bucket_name = "my-unique-root-bucket"
  # workspace_name   = "my-workspace"
}
