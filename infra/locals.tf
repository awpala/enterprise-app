locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      project      = var.project
      environment  = var.environment
      "managed-by" = "terraform"
    },
    var.tags,
  )
}
