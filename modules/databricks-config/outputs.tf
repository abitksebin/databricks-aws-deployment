output "cluster_id" {
  description = "ID of the shared cluster."
  value       = databricks_cluster.shared.id
}

output "cluster_policy_id" {
  description = "ID of the shared cluster policy."
  value       = databricks_cluster_policy.shared.id
}

output "group_name" {
  description = "Name of the data engineers group."
  value       = databricks_group.data_engineers.display_name
}
