variable "workspace_url" {
  description = "Workspace URL (output of the databricks-workspace module), e.g. https://dbc-xxxx.cloud.databricks.com."
  type        = string
}

variable "prefix" {
  description = "Short name prefix applied to every resource, e.g. dbx-dev."
  type        = string
}

variable "tags" {
  description = "Custom tags applied to cluster nodes (they show up in AWS cost reports)."
  type        = map(string)
  default     = {}
}

variable "group_name" {
  description = "Name of the workspace-local group that is allowed to use the policy and shared cluster."
  type        = string
  default     = "data-engineers"
}

variable "node_type_id" {
  description = "Default instance type for the shared cluster. Check your AWS vCPU quota for this family before applying."
  type        = string
  default     = "m5d.xlarge"
}

variable "allowed_node_types" {
  description = "Instance types the cluster policy allows. Must include node_type_id."
  type        = list(string)
  default     = ["m5d.large", "m5d.xlarge", "m5d.2xlarge"]
}

variable "max_workers" {
  description = "Maximum autoscale workers for the shared cluster, and the upper limit in the cluster policy."
  type        = number
  default     = 2
}

variable "autotermination_minutes" {
  description = "Default idle time before clusters shut down. Keeps dev costs down."
  type        = number
  default     = 30
}

variable "max_autotermination_minutes" {
  description = "Upper limit for autotermination that the cluster policy enforces."
  type        = number
  default     = 120
}
