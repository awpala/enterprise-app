output "log_group_names" {
  description = "CloudWatch log-group names keyed by logical service."
  value = {
    api         = aws_cloudwatch_log_group.service["api"].name
    ui          = aws_cloudwatch_log_group.service["ui"].name
    data_engine = aws_cloudwatch_log_group.service["data-engine"].name
    rabbitmq    = aws_cloudwatch_log_group.service["rabbitmq"].name
    migrations  = aws_cloudwatch_log_group.service["migrations"].name
  }
}

output "dashboard_name" {
  description = "CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
