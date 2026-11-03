# -----------------------------------------------------------------------------
# Network module: customer-managed VPC for a Databricks workspace on AWS.
#
# Layout
#   - 2-3 private subnets (one per AZ): Databricks cluster nodes live here with
#     no public IPs.
#   - 1+ public subnets: hold only the NAT gateway(s) and route to the internet
#     gateway.
#   - A security group that follows the Databricks customer-managed VPC rules.
#   - Optional VPC endpoints so AWS service traffic stays on the AWS network.
#
# Outputs feed the databricks-workspace module (via Terragrunt dependencies).
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"

  # Exclude Local Zones and Wavelength Zones, which Databricks cannot use.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # First N zones in the region, e.g. ["eu-west-2a", "eu-west-2b"].
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Number of NAT gateways (and therefore public subnets) to create.
  nat_count = var.single_nat_gateway ? 1 : var.az_count

  # Outbound (egress) ports Databricks nodes need to reach the control plane
  # and other services. See "Configure a customer-managed VPC" in the Databricks
  # docs for the authoritative list.
  egress_rules = {
    https = {
      from        = 443
      to          = 443
      description = "Databricks infrastructure, cloud data sources and library repositories"
    }
    metastore = {
      from        = 3306
      to          = 3306
      description = "Legacy Hive metastore"
    }
    privatelink = {
      from        = 6666
      to          = 6666
      description = "PrivateLink (harmless if PrivateLink is not used)"
    }
    fips = {
      from        = 2443
      to          = 2443
      description = "FIPS-compliant encryption endpoints"
    }
    control_plane = {
      from        = 8443
      to          = 8451
      description = "Control plane to data plane internal calls and Unity Catalog services"
    }
  }
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Databricks requires both DNS settings to be enabled.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

# Private subnets: /20 each (about 4,000 IPs). Every Databricks node uses one IP,
# and AWS reserves 5 per subnet. Databricks accepts subnets between /17 and /26.
resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)

  tags = {
    Name = "${var.prefix}-private-${local.azs[count.index]}"
  }
}

# Public subnets: /24, used only to host NAT gateways. Offset by 200 so they
# can never overlap the private /20 blocks above.
resource "aws_subnet" "public" {
  count = local.nat_count

  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 200 + count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.prefix}-public-${local.azs[count.index]}"
  }
}

# -----------------------------------------------------------------------------
# Internet and NAT
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

# Static public IP(s) for outbound traffic. Handy for firewall allow-lists
# (see the nat_public_ips output).
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-nat-eip-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.prefix}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Routing
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = local.nat_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ so that, with single_nat_gateway = false, each
# AZ routes through its own NAT gateway. With a single NAT they all share it.
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${var.prefix}-private-rt-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------------
# Security group for Databricks cluster nodes
# -----------------------------------------------------------------------------

resource "aws_security_group" "databricks" {
  name        = "${var.prefix}-databricks-sg"
  description = "Databricks cluster nodes (customer-managed VPC)"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}-databricks-sg"
  }
}

# Cluster nodes must be able to talk to each other on all ports. The rules
# reference the security group itself, so only members of the group are allowed.
resource "aws_vpc_security_group_ingress_rule" "self_tcp" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster TCP"
}

resource "aws_vpc_security_group_ingress_rule" "self_udp" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster UDP"
}

resource "aws_vpc_security_group_egress_rule" "self_tcp" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster TCP"
}

resource "aws_vpc_security_group_egress_rule" "self_udp" {
  security_group_id            = aws_security_group.databricks.id
  referenced_security_group_id = aws_security_group.databricks.id
  ip_protocol                  = "udp"
  from_port                    = 0
  to_port                      = 65535
  description                  = "Intra-cluster UDP"
}

# Outbound access to the Databricks control plane and AWS services.
resource "aws_vpc_security_group_egress_rule" "internet" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.databricks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value.from
  to_port           = each.value.to
  description       = each.value.description
}

# -----------------------------------------------------------------------------
# VPC endpoints (optional)
# -----------------------------------------------------------------------------

# S3 gateway endpoint: free, and keeps S3 traffic (including the DBFS root
# bucket and Unity Catalog storage) off the NAT gateway.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = {
    Name = "${var.prefix}-s3-endpoint"
  }
}

# Interface endpoints need their own security group that allows HTTPS from
# inside the VPC.
resource "aws_security_group" "endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  name        = "${var.prefix}-vpce-sg"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}-vpce-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from the VPC"
}

# STS (credential vending) and Kinesis (Databricks log delivery) are the two
# AWS services Databricks recommends private endpoints for.
resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_interface_endpoints ? toset(["sts", "kinesis-streams"]) : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.prefix}-${each.key}-endpoint"
  }
}
