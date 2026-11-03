output "metastore_id" {
  description = "ID of the metastore assigned to the workspace (created here or supplied via existing_metastore_id)."
  value       = local.active_metastore
}

output "metastore_bucket_name" {
  description = "Metastore root S3 bucket, or null when an existing metastore is used."
  value       = one(aws_s3_bucket.metastore[*].id)
}

output "uc_access_role_arn" {
  description = "ARN of the IAM role Unity Catalog assumes, or null when an existing metastore is used."
  value       = one(aws_iam_role.uc_access[*].arn)
}
