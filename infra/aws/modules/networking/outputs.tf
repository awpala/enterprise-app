output "vpc_id" {
  description = "Application VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by internet-facing load balancers."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS, RDS, and EFS."
  value       = aws_subnet.private[*].id
}
