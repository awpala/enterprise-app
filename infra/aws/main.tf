data "aws_caller_identity" "current" {}

resource "random_password" "postgres" {
  length           = 24
  special          = true
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#%*-_=+?"
}

resource "random_password" "rabbitmq" {
  length           = 24
  special          = true
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#%*-_=+?"
}

module "networking" {
  source = "./modules/networking"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = var.availability_zone_count
  single_nat_gateway      = var.single_nat_gateway
  tags                    = local.common_tags
}

module "container_registry" {
  source = "./modules/container-registry"

  repositories = local.container_repositories
  tags         = local.common_tags
}

module "load_balancer" {
  source = "./modules/load-balancer"

  name_prefix         = local.name_prefix
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  deletion_protection = var.environment == "prod"
  tags                = local.common_tags
}

module "cloudfront" {
  source = "./modules/cloudfront"

  name_prefix            = local.name_prefix
  load_balancer_dns_name = module.load_balancer.dns_name
  tags                   = local.common_tags
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  name_prefix                     = local.name_prefix
  vpc_id                          = module.networking.vpc_id
  load_balancer_security_group_id = module.load_balancer.security_group_id
  tags                            = local.common_tags
}

module "postgres" {
  source = "./modules/postgres"

  name_prefix              = local.name_prefix
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  client_security_group_id = module.ecs_cluster.task_security_group_id
  administrator_username   = var.postgres_admin_username
  administrator_password   = random_password.postgres.result
  database_name            = var.postgres_database_name
  instance_class           = var.postgres_instance_class
  multi_az                 = var.postgres_multi_az
  deletion_protection      = var.environment == "prod"
  skip_final_snapshot      = var.environment != "prod"
  tags                     = local.common_tags
}

module "cognito" {
  source = "./modules/cognito"

  name_prefix                     = local.name_prefix
  aws_region                      = var.aws_region
  domain_prefix                   = var.cognito_domain_prefix
  application_url                 = module.cloudfront.application_url
  enable_google_identity_provider = var.enable_google_identity_provider
  google_client_id                = var.google_client_id
  google_client_secret            = var.google_client_secret
  upstream_oidc                   = var.upstream_oidc
  upstream_saml                   = var.upstream_saml
  tags                            = local.common_tags
}

module "secrets_manager" {
  source = "./modules/secrets-manager"

  name_prefix             = local.name_prefix
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  postgres_host           = module.postgres.address
  postgres_port           = module.postgres.port
  postgres_database       = var.postgres_database_name
  postgres_username       = var.postgres_admin_username
  postgres_password       = random_password.postgres.result
  rabbitmq_password       = random_password.rabbitmq.result
  tags                    = local.common_tags
}

module "ecs_iam" {
  source = "./modules/ecs-iam"

  name_prefix = local.name_prefix
  secret_arns = [
    module.secrets_manager.postgres_connection_string_arn,
    module.secrets_manager.rabbitmq_password_arn,
  ]
  tags = local.common_tags
}

module "observability" {
  source = "./modules/observability"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  log_retention_days = var.log_retention_days
  cluster_name       = module.ecs_cluster.cluster_name
  service_names      = local.ecs_service_names
  alb_arn_suffix     = module.load_balancer.arn_suffix
  tags               = local.common_tags
}

module "rabbitmq" {
  source = "./modules/rabbitmq"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  cluster_arn            = module.ecs_cluster.cluster_arn
  namespace_id           = module.ecs_cluster.namespace_id
  namespace_name         = module.ecs_cluster.namespace_name
  task_security_group_id = module.ecs_cluster.task_security_group_id
  execution_role_arn     = module.ecs_iam.execution_role_arn
  task_role_arn          = module.ecs_iam.task_role_arn
  image                  = "rabbitmq:4-management"
  username               = var.rabbitmq_username
  password_secret_arn    = module.secrets_manager.rabbitmq_password_arn
  log_group_name         = module.observability.log_group_names["rabbitmq"]
  tags                   = local.common_tags
}

module "container_services" {
  source = "./modules/container-services"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  cluster_arn            = module.ecs_cluster.cluster_arn
  cluster_name           = module.ecs_cluster.cluster_name
  private_subnet_ids     = module.networking.private_subnet_ids
  task_security_group_id = module.ecs_cluster.task_security_group_id
  execution_role_arn     = module.ecs_iam.execution_role_arn
  task_role_arn          = module.ecs_iam.task_role_arn
  image_uris             = local.image_uris
  desired_count          = var.desired_count
  maximum_desired_count  = var.maximum_desired_count
  api_target_group_arn   = module.load_balancer.api_target_group_arn
  ui_target_group_arn    = module.load_balancer.ui_target_group_arn
  rabbitmq_host          = module.rabbitmq.host
  rabbitmq_username      = var.rabbitmq_username
  rabbitmq_password_arn  = module.secrets_manager.rabbitmq_password_arn
  postgres_secret_arn    = module.secrets_manager.postgres_connection_string_arn
  application_url        = module.cloudfront.application_url
  auth_authority         = module.cognito.authority
  auth_audience          = module.cognito.api_audience
  auth_client_id         = module.cognito.client_id
  auth_scope             = module.cognito.api_scope
  auth_logout_endpoint   = module.cognito.managed_login_url
  allow_dev_auth         = var.allow_dev_auth
  allow_guest_auth       = var.allow_guest_auth
  log_group_names        = module.observability.log_group_names
  tags                   = local.common_tags
}
