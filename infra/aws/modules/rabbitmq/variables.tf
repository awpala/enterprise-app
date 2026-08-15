variable "name_prefix" {
  description = "Prefix applied to RabbitMQ resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region used by the awslogs driver."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing RabbitMQ and EFS."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by RabbitMQ tasks and EFS mount targets."
  type        = list(string)
}

variable "cluster_arn" {
  description = "ECS cluster ARN that runs RabbitMQ."
  type        = string
}

variable "namespace_id" {
  description = "Cloud Map namespace ID used for RabbitMQ discovery."
  type        = string
}

variable "namespace_name" {
  description = "Cloud Map namespace name used to construct the RabbitMQ host."
  type        = string
}

variable "task_security_group_id" {
  description = "Shared ECS task security group ID."
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

variable "image" {
  description = "Pinned RabbitMQ container image."
  type        = string
}

variable "username" {
  description = "RabbitMQ application username."
  type        = string
}

variable "password_secret_arn" {
  description = "Secrets Manager ARN containing the RabbitMQ password."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group for RabbitMQ."
  type        = string
}

variable "tags" {
  description = "Tags applied to every RabbitMQ resource."
  type        = map(string)
}
