locals {
  log_names = toset(["api", "ui", "data-engine", "rabbitmq", "migrations"])
}

resource "aws_cloudwatch_log_group" "service" {
  for_each = local.log_names

  name              = "/ecs/${var.name_prefix}/${each.value}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "service_cpu" {
  for_each = var.service_names

  alarm_name          = "${var.name_prefix}-${each.key}-high-cpu"
  alarm_description   = "${each.value} CPU exceeded 80 percent for ten minutes."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU utilization"
          region = var.aws_region
          stat   = "Average"
          period = 300
          view   = "timeSeries"
          metrics = [for service_name in values(var.service_names) : [
            "AWS/ECS",
            "CPUUtilization",
            "ClusterName",
            var.cluster_name,
            "ServiceName",
            service_name,
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Load balancer requests and server errors"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 8
        properties = {
          title  = "Recent service errors"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.service["api"].name}' | SOURCE '${aws_cloudwatch_log_group.service["data-engine"].name}' | fields @timestamp, @log, @message | filter @message like /(?i)(error|exception|failed)/ | sort @timestamp desc | limit 100"
        }
      },
    ]
  })
}
