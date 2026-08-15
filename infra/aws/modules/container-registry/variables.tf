variable "repositories" {
  description = "Physical ECR repository names keyed by cloud-neutral logical image name."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to every registry resource."
  type        = map(string)
}
