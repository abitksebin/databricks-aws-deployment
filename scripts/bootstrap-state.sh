#!/usr/bin/env bash
#
# Creates the Terraform remote state backend: an S3 bucket (versioned, encrypted,
# private) and a DynamoDB table for state locking.
#
# Run once per environment, before the first `terragrunt apply`. Safe to re-run:
# it skips anything that already exists.
#
# Usage:
#   ./scripts/bootstrap-state.sh <aws_region> <state_bucket> <lock_table>
#
# Example:
#   ./scripts/bootstrap-state.sh eu-west-2 my-unique-tfstate-dbx-dev tfstate-lock-dbx-dev
#
# The values must match state_bucket / state_lock_table / region in
# live/<env>/env.hcl. Requires the AWS CLI with credentials for the target account.

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <aws_region> <state_bucket> <lock_table>" >&2
  exit 1
fi

REGION="$1"
BUCKET="$2"
TABLE="$3"

# --- S3 bucket -----------------------------------------------------------------

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket ${BUCKET} already exists, skipping creation."
else
  echo "Creating bucket ${BUCKET} in ${REGION}..."
  # us-east-1 is the only region that must NOT receive a LocationConstraint.
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

# Versioning lets you recover a previous state file after a bad apply.
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

# State can contain sensitive values, so encrypt it at rest.
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# State must never be public.
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# --- DynamoDB lock table -------------------------------------------------------

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Table ${TABLE} already exists, skipping creation."
else
  echo "Creating lock table ${TABLE}..."
  # Terraform's S3 backend requires a string hash key named exactly "LockID".
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --region "${REGION}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

echo "Done. State backend ready: s3://${BUCKET} (lock table: ${TABLE})"
