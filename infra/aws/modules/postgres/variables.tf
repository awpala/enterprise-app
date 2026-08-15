variable "name_prefix" {
  description = "Prefix applied to PostgreSQL resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by the RDS subnet group."
  type        = list(string)
}

variable "client_security_group_id" {
  description = "Security group allowed to connect to PostgreSQL."
  type        = string
}

variable "administrator_username" {
  description = "RDS administrator username."
  type        = string
}

variable "administrator_password" {
  description = "RDS administrator password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Initial application database name."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "multi_az" {
  description = "Whether RDS maintains a synchronous standby."
  type        = bool
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether deletion skips a final database snapshot."
  type        = bool
}

variable "tags" {
  description = "Tags applied to every PostgreSQL resource."
  type        = map(string)
}
