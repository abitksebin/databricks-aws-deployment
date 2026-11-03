variable "region" {
  description = "AWS region for the VPC (must match the region of the Databricks workspace)."
  type        = string
}

variable "prefix" {
  description = "Short name prefix applied to every resource, e.g. dbx-dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.prefix))
    error_message = "prefix must be 3-20 characters: lowercase letters, digits and hyphens only."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the VPC. Must be a /16: the private subnets are /20 and the
    public (NAT) subnets are /24, both carved out of it with cidrsubnet().
    Pick a range that does not overlap networks you may peer with later.
  EOT
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid /16 CIDR block, e.g. 10.10.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones (and private subnets). Databricks needs at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    true  = one shared NAT gateway (cheapest; fine for dev, but a single-AZ
            point of failure for outbound traffic).
    false = one NAT gateway per AZ (recommended for production).
  EOT
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Create an S3 gateway endpoint (free). Keeps S3 traffic off the NAT gateway and cuts data-processing cost."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = <<-EOT
    Create interface endpoints for STS and Kinesis, which Databricks recommends
    for customer-managed VPCs. They carry an hourly cost per AZ, so they are
    off by default for dev.
  EOT
  type        = bool
  default     = false
}
