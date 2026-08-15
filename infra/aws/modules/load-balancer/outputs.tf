output "arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "Application Load Balancer ARN suffix used by CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "AWS-generated load balancer DNS name."
  value       = aws_lb.this.dns_name
}

output "security_group_id" {
  description = "Load balancer security group ID."
  value       = aws_security_group.this.id
}

output "api_target_group_arn" {
  description = "Target group ARN for the API service."
  value       = aws_lb_target_group.api.arn
}

output "ui_target_group_arn" {
  description = "Target group ARN for the UI service."
  value       = aws_lb_target_group.ui.arn
}
