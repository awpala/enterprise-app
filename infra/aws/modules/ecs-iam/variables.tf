variable "name_prefix" {
  description = "Prefix applied to ECS IAM role names."
  type        = string
}

variable "secret_arns" {
  description = "Secrets task definitions may inject at startup."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to ECS IAM roles."
  type        = map(string)
}
