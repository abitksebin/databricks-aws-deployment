output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ) that Databricks cluster nodes run in."
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "Security group ID for Databricks cluster nodes."
  value       = aws_security_group.databricks.id
}

output "nat_public_ips" {
  description = "Static public IP(s) used for outbound traffic. Add these to external firewall allow-lists."
  value       = aws_eip.nat[*].public_ip
}
