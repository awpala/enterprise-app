locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      project      = var.project
      environment  = var.environment
      "managed-by" = "terraform"
      cloud        = "aws"
    },
    var.tags,
  )

  container_repositories = {
    ea-api         = "${local.name_prefix}-api"
    ea-data-engine = "${local.name_prefix}-data-engine"
    ea-migrations  = "${local.name_prefix}-migrations"
    ea-ui          = "${local.name_prefix}-ui"
  }

  image_uris = {
    api         = "${module.container_registry.repository_urls["ea-api"]}:${var.image_tag}"
    data_engine = "${module.container_registry.repository_urls["ea-data-engine"]}:${var.image_tag}"
    migrations  = "${module.container_registry.repository_urls["ea-migrations"]}:${var.image_tag}"
    ui          = "${module.container_registry.repository_urls["ea-ui"]}:${var.image_tag}"
  }

  ecs_service_names = {
    api         = "${local.name_prefix}-api"
    data_engine = "${local.name_prefix}-data-engine"
    ui          = "${local.name_prefix}-ui"
    rabbitmq    = "${local.name_prefix}-rabbitmq"
  }
}
