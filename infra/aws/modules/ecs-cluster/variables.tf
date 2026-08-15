variable "name_prefix" {
  description = "Prefix applied to ECS foundation resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which ECS task networking and service discovery are created."
  type        = string
}

variable "load_balancer_security_group_id" {
  description = "Security group allowed to reach HTTP ports on ECS tasks."
  type        = string
}

variable "tags" {
  description = "Tags applied to every ECS foundation resource."
  type        = map(string)
}
