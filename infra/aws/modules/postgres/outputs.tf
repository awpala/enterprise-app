output "address" {
  description = "RDS PostgreSQL hostname."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS PostgreSQL port."
  value       = aws_db_instance.this.port
}

output "id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "security_group_id" {
  description = "Database security group ID."
  value       = aws_security_group.this.id
}
