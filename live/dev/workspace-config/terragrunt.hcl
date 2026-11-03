# Unit 4 of 4: cluster policy, group, shared cluster and permissions inside the
# workspace. The service principal must be a workspace admin.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/databricks-config"
}

dependency "workspace" {
  config_path = "../workspace"

  # Mocks are limited to init/validate. `plan` needs a real workspace URL
  # because the module looks up the current Databricks Runtime version through
  # the workspace API.
  mock_outputs = {
    workspace_url = "https://example.cloud.databricks.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

# Order only: the metastore should be assigned before the cluster is created.
# No outputs are consumed from this unit.
dependencies {
  paths = ["../unity-catalog"]
}

inputs = {
  prefix = local.env.prefix
  tags   = local.env.tags

  workspace_url = dependency.workspace.outputs.workspace_url

  # Check your AWS vCPU quota for this instance family before applying. With
  # max_workers = 2 the cluster can reach 3 nodes x 4 vCPUs = 12 vCPUs.
  node_type_id       = "m5d.xlarge"
  allowed_node_types = ["m5d.large", "m5d.xlarge", "m5d.2xlarge"]
  max_workers        = 2

  group_name = "data-engineers"
}
