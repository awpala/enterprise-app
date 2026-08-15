variable "name_prefix" {
  description = "Prefix applied to observability resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region displayed by dashboard widgets."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
}

variable "cluster_name" {
  description = "ECS cluster dimension used by dashboards and alarms."
  type        = string
}

variable "service_names" {
  description = "ECS service names keyed by logical service."
  type        = map(string)
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metric dimensions."
  type        = string
}

variable "tags" {
  description = "Tags applied to observability resources that support tags."
  type        = map(string)
}
