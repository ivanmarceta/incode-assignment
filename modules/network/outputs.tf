output "vpc_id" {
  description = "VPC identifier."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "database_subnet_ids" {
  description = "Database subnet identifiers."
  value       = [for subnet in aws_subnet.database : subnet.id]
}

output "internet_gateway_id" {
  description = "Internet gateway identifier."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT gateway identifier when enabled."
  value       = try(aws_nat_gateway.main[0].id, null)
}
