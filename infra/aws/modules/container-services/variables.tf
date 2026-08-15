variable "name_prefix" {
  description = "Prefix applied to application workload names."
  type        = string
}

variable "aws_region" {
  description = "AWS region used by container log drivers."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN that runs application workloads."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name used by Application Auto Scaling resource identifiers."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by Fargate tasks."
  type        = list(string)
}

variable "task_security_group_id" {
  description = "Security group attached to Fargate tasks."
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "Application task role ARN."
  type        = string
}

variable "image_uris" {
  description = "Immutable image URIs for API, UI, data engine, and migrations."
  type = object({
    api         = string
    ui          = string
    data_engine = string
    migrations  = string
  })
}

variable "desired_count" {
  description = "Minimum and initial count for continuously running application services."
  type        = number
}

variable "maximum_desired_count" {
  description = "Maximum autoscaled count for continuously running application services."
  type        = number

  validation {
    condition     = var.maximum_desired_count >= var.desired_count
    error_message = "maximum_desired_count must be greater than or equal to desired_count."
  }
}

variable "api_target_group_arn" {
  description = "ALB target group ARN for the API service."
  type        = string
}

variable "ui_target_group_arn" {
  description = "ALB target group ARN for the UI service."
  type        = string
}

variable "rabbitmq_host" {
  description = "Private RabbitMQ service-discovery hostname."
  type        = string
}

variable "rabbitmq_username" {
  description = "RabbitMQ application username."
  type        = string
}

variable "rabbitmq_password_arn" {
  description = "Secrets Manager ARN containing the RabbitMQ password."
  type        = string
}

variable "postgres_secret_arn" {
  description = "Secrets Manager ARN containing the PostgreSQL connection string."
  type        = string
}

variable "application_url" {
  description = "Public shared origin used by UI, API, and CORS."
  type        = string
}

variable "auth_authority" {
  description = "OIDC authority supplied to API and UI."
  type        = string
}

variable "auth_audience" {
  description = "Audience supplied to API token validation."
  type        = string
}

variable "auth_client_id" {
  description = "Public OIDC client ID supplied to API and UI."
  type        = string
}

variable "auth_scope" {
  description = "Required API OAuth scope."
  type        = string
}

variable "auth_logout_endpoint" {
  description = "Provider logout endpoint used by the UI adapter."
  type        = string
}

variable "allow_dev_auth" {
  description = "Whether synthetic developer authentication is enabled."
  type        = bool
}

variable "allow_guest_auth" {
  description = "Whether synthetic guest authentication is enabled."
  type        = bool
}

variable "log_group_names" {
  description = "CloudWatch log-group names keyed by logical service."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to application ECS resources."
  type        = map(string)
}
