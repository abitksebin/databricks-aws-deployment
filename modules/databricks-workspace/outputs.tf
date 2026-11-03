output "workspace_id" {
  description = "Numeric Databricks workspace ID (used to assign the Unity Catalog metastore)."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL, e.g. https://dbc-xxxx.cloud.databricks.com. Consumed by the workspace-config unit."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role Databricks assumes."
  value       = aws_iam_role.cross_account.arn
}

output "root_bucket_name" {
  description = "Name of the workspace root S3 bucket."
  value       = aws_s3_bucket.root.bucket
}
