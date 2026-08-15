variable "name_prefix" {
  description = "Prefix applied to load-balancer resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which the load balancer and target groups are created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the internet-facing load balancer."
  type        = list(string)
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled on the load balancer."
  type        = bool
}

variable "tags" {
  description = "Tags applied to every load-balancer resource."
  type        = map(string)
}
