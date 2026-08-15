variable "name_prefix" {
  description = "Prefix applied to CloudFront resources."
  type        = string
}

variable "load_balancer_dns_name" {
  description = "AWS-generated ALB DNS name used as the CloudFront origin."
  type        = string
}

variable "tags" {
  description = "Tags applied to the CloudFront distribution."
  type        = map(string)
}
