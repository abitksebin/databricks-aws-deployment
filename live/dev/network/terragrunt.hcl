# Unit 1 of 4: VPC, subnets, NAT, security group and VPC endpoints.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/network"
}

inputs = {
  region = local.env.region
  prefix = local.env.prefix
  tags   = local.env.tags

  # Must be a /16. Pick a range that will not overlap networks you peer with.
  vpc_cidr = "10.10.0.0/16"

  # Two AZs is the Databricks minimum.
  az_count = 2

  # One shared NAT gateway keeps dev cheap. Set to false for production so each
  # AZ has its own NAT gateway.
  single_nat_gateway = true

  # S3 gateway endpoint is free. STS/Kinesis interface endpoints cost money per
  # AZ per hour, so they are off for dev.
  enable_s3_endpoint         = true
  enable_interface_endpoints = false
}
