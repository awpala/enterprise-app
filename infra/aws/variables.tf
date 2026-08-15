variable "aws_region" {
  description = "AWS region in which the application stack is deployed."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "ea"
}

variable "environment" {
  description = "Environment name such as dev or prod."
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Immutable image tag deployed for all application containers."
  type        = string
  default     = "latest"
}

variable "vpc_cidr" {
  description = "CIDR allocated to the application VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones used for public and private subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway to reduce non-production cost. Set false in production for zonal resilience."
  type        = bool
  default     = true
}

variable "postgres_admin_username" {
  description = "Administrator username for RDS PostgreSQL."
  type        = string
  default     = "eaadmin"
}

variable "postgres_database_name" {
  description = "Application database created on RDS PostgreSQL."
  type        = string
  default     = "ea"
}

variable "postgres_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "postgres_multi_az" {
  description = "Whether RDS maintains a synchronous standby in another availability zone."
  type        = bool
  default     = false
}

variable "rabbitmq_username" {
  description = "RabbitMQ application username."
  type        = string
  default     = "ea"
}

variable "cognito_domain_prefix" {
  description = "Globally unique Cognito managed-login domain prefix."
  type        = string
}

variable "enable_google_identity_provider" {
  description = "Create the Google Cognito identity provider. Credentials must be supplied out of band."
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth client ID used by Cognito when Google federation is enabled."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth client secret used by Cognito when Google federation is enabled."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "upstream_oidc" {
  description = "Optional enterprise or Microsoft-account OIDC provider federated through Cognito."
  type = object({
    name          = string
    issuer        = string
    client_id     = string
    client_secret = string
    scopes        = optional(string, "openid profile email")
  })
  default   = null
  nullable  = true
  sensitive = true
}

variable "upstream_saml" {
  description = "Optional enterprise SAML identity provider federated through Cognito."
  type = object({
    name         = string
    metadata_url = string
    idp_sign_out = optional(bool, true)
  })
  default  = null
  nullable = true
}

variable "allow_dev_auth" {
  description = "Enable the synthetic developer principal. Must be false in production."
  type        = bool
  default     = false
}

variable "allow_guest_auth" {
  description = "Enable the synthetic demo guest principal. Keep disabled unless explicitly accepted for the environment."
  type        = bool
  default     = false
}

variable "desired_count" {
  description = "Minimum and initial task count for the API, UI, and data-engine ECS services."
  type        = number
  default     = 1
}

variable "maximum_desired_count" {
  description = "Maximum autoscaled task count for the API, UI, and data-engine ECS services."
  type        = number
  default     = 3

  validation {
    condition     = var.maximum_desired_count >= var.desired_count
    error_message = "maximum_desired_count must be greater than or equal to desired_count."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags merged with the mandatory project, environment, managed-by, and cloud tags."
  type        = map(string)
  default     = {}
}
