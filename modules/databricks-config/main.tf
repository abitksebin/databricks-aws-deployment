# -----------------------------------------------------------------------------
# Workspace configuration module: baseline settings inside the workspace.
#
#   - A cluster policy that caps cost (allowed instance types, autotermination,
#     maximum size).
#   - A `data-engineers` group.
#   - A shared autoscaling cluster governed by that policy.
#   - Permissions tying the group to the policy and cluster.
#
# Catalogs, schemas and grants are deliberately not created here.
# -----------------------------------------------------------------------------

# Latest long-term-support Databricks Runtime, looked up at plan time so the
# configuration does not go stale when versions are retired.
data "databricks_spark_version" "lts" {
  long_term_support = true
}

# -----------------------------------------------------------------------------
# Cluster policy
# -----------------------------------------------------------------------------

resource "databricks_cluster_policy" "shared" {
  name = "${var.prefix}-shared-policy"

  # Policy definition language: each key is a cluster attribute. "range" bounds a
  # number, "allowlist" restricts to listed values, "unlimited" only sets a
  # default.
  definition = jsonencode({
    "spark_version" = {
      type         = "unlimited"
      defaultValue = data.databricks_spark_version.lts.id
    }
    "node_type_id" = {
      type         = "allowlist"
      values       = var.allowed_node_types
      defaultValue = var.node_type_id
    }
    "autotermination_minutes" = {
      type         = "range"
      minValue     = 10
      maxValue     = var.max_autotermination_minutes
      defaultValue = var.autotermination_minutes
    }
    "autoscale.max_workers" = {
      type         = "range"
      maxValue     = var.max_workers
      defaultValue = var.max_workers
    }
  })
}

# -----------------------------------------------------------------------------
# Group
# -----------------------------------------------------------------------------

# Workspace-local group. For production, sync groups from your identity provider
# (SCIM) at account level instead and reference those.
resource "databricks_group" "data_engineers" {
  display_name = var.group_name
}

# -----------------------------------------------------------------------------
# Shared cluster
# -----------------------------------------------------------------------------

resource "databricks_cluster" "shared" {
  cluster_name = "${var.prefix}-shared"

  spark_version = data.databricks_spark_version.lts.id
  node_type_id  = var.node_type_id

  # Governed by the policy above; defaults from the policy fill any gaps.
  policy_id                   = databricks_cluster_policy.shared.id
  apply_policy_default_values = true

  autotermination_minutes = var.autotermination_minutes

  # "Standard" (formerly shared) access mode: multiple users, Unity Catalog
  # enforced.
  data_security_mode = "USER_ISOLATION"

  autoscale {
    min_workers = 1
    max_workers = var.max_workers
  }

  aws_attributes {
    # Spot workers with on-demand fallback; the driver stays on-demand so a
    # spot reclaim cannot kill the whole cluster.
    availability    = "SPOT_WITH_FALLBACK"
    first_on_demand = 1
    zone_id         = "auto"
  }

  custom_tags = var.tags
}

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------

resource "databricks_permissions" "policy_usage" {
  cluster_policy_id = databricks_cluster_policy.shared.id

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }
}

resource "databricks_permissions" "cluster_usage" {
  cluster_id = databricks_cluster.shared.id

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_RESTART"
  }
}
