variable "name_prefix" {
  description = "Prefix applied to networking resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR allocated to the VPC."
  type        = string
}

variable "availability_zone_count" {
  description = "Number of availability zones and subnet pairs."
  type        = number
}

variable "single_nat_gateway" {
  description = "Whether all private subnets share one NAT gateway."
  type        = bool
}

variable "tags" {
  description = "Tags applied to every networking resource."
  type        = map(string)
}
