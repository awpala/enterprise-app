locals {
  adot_config = <<-YAML
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}
    exporters:
      awsxray: {}
      awsemf:
        namespace: EnterpriseApp
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [awsxray]
        metrics:
          receivers: [otlp]
          processors: [batch]
          exporters: [awsemf]
  YAML

  common_adot = {
    name      = "adot-collector"
    image     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.48.0"
    essential = false
    command   = ["--config=env:AOT_CONFIG_CONTENT"]
    environment = [
      { name = "AOT_CONFIG_CONTENT", value = local.adot_config },
    ]
  }

  api_container = {
    name      = "api"
    image     = var.image_uris.api
    essential = true
    portMappings = [
      { containerPort = 8000, hostPort = 8000, protocol = "tcp", appProtocol = "http" },
    ]
    environment = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "ASPNETCORE_URLS", value = "http://+:8000" },
      { name = "RabbitMQ__Host", value = var.rabbitmq_host },
      { name = "RabbitMQ__Username", value = var.rabbitmq_username },
      { name = "Seeding__Enabled", value = "true" },
      { name = "Seeding__SeedPath", value = "/app/seed" },
      { name = "Authentication__Enabled", value = "true" },
      { name = "Authentication__Provider", value = "cognito" },
      { name = "Authentication__AllowDev", value = tostring(var.allow_dev_auth) },
      { name = "Authentication__AllowGuest", value = tostring(var.allow_guest_auth) },
      { name = "Authentication__Authority", value = var.auth_authority },
      { name = "Authentication__Audience", value = var.auth_audience },
      { name = "Authentication__ClientId", value = var.auth_client_id },
      { name = "Authentication__RequiredScope", value = var.auth_scope },
      { name = "Cors__AllowedOrigins__0", value = var.application_url },
      { name = "Observability__Exporter", value = "otlp" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },
      { name = "OTEL_SERVICE_NAME", value = "ea-api" },
    ]
    secrets = [
      { name = "ConnectionStrings__DefaultConnection", valueFrom = var.postgres_secret_arn },
      { name = "RabbitMQ__Password", valueFrom = var.rabbitmq_password_arn },
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -fsS http://localhost:8000/health/live || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_names.api
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "api"
      }
    }
  }

  ui_container = {
    name      = "ui"
    image     = var.image_uris.ui
    essential = true
    portMappings = [
      { containerPort = 3000, hostPort = 3000, protocol = "tcp", appProtocol = "http" },
    ]
    environment = [
      { name = "PORT", value = "3000" },
      { name = "HOSTNAME", value = "0.0.0.0" },
      { name = "DEPLOYMENT_TARGET", value = "aws" },
      { name = "API_URL", value = var.application_url },
      { name = "AUTH_PROVIDER", value = "cognito" },
      { name = "AUTH_AUTHORITY", value = var.auth_authority },
      { name = "AUTH_CLIENT_ID", value = var.auth_client_id },
      { name = "AUTH_API_SCOPE", value = var.auth_scope },
      { name = "AUTH_LOGOUT_ENDPOINT", value = var.auth_logout_endpoint },
      { name = "ENABLE_DEV_AUTH", value = tostring(var.allow_dev_auth) },
      { name = "ENABLE_GUEST_AUTH", value = tostring(var.allow_guest_auth) },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
      { name = "OTEL_SERVICE_NAME", value = "ea-ui" },
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:3000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_names.ui
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ui"
      }
    }
  }

  data_engine_container = {
    name      = "data-engine"
    image     = var.image_uris.data_engine
    essential = true
    environment = [
      { name = "RABBITMQ_HOST", value = var.rabbitmq_host },
      { name = "RABBITMQ_PORT", value = "5672" },
      { name = "RABBITMQ_USER", value = var.rabbitmq_username },
      { name = "LOG_LEVEL", value = "INFO" },
      { name = "OBSERVABILITY_EXPORTER", value = "otlp" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },
      { name = "OTEL_SERVICE_NAME", value = "ea-data-engine" },
      { name = "OTEL_TRACES_SAMPLER", value = "parentbased_traceidratio" },
      { name = "OTEL_TRACES_SAMPLER_ARG", value = "0.2" },
    ]
    secrets = [
      { name = "RABBITMQ_PASSWORD", valueFrom = var.rabbitmq_password_arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_names.data_engine
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "data-engine"
      }
    }
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([
    local.api_container,
    merge(local.common_adot, {
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_names.api
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "adot"
        }
      }
    }),
  ])
  tags = var.tags
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "${var.name_prefix}-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([
    local.ui_container,
    merge(local.common_adot, {
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_names.ui
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "adot"
        }
      }
    }),
  ])
  tags = var.tags
}

resource "aws_ecs_task_definition" "data_engine" {
  family                   = "${var.name_prefix}-data-engine"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([
    local.data_engine_container,
    merge(local.common_adot, {
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_names.data_engine
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "adot"
        }
      }
    }),
  ])
  tags = var.tags
}

resource "aws_ecs_task_definition" "migrations" {
  family                   = "${var.name_prefix}-migrations"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "migrations"
      image     = var.image_uris.migrations
      essential = true
      secrets = [
        { name = "ConnectionStrings__DefaultConnection", valueFrom = var.postgres_secret_arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_names.migrations
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "migrations"
        }
      }
    },
  ])
  tags = var.tags
}

resource "aws_ecs_service" "api" {
  name                              = "${var.name_prefix}-api"
  cluster                           = var.cluster_arn
  task_definition                   = aws_ecs_task_definition.api.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  enable_execute_command            = true
  propagate_tags                    = "SERVICE"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = 8000
  }

  tags = var.tags
}

resource "aws_ecs_service" "ui" {
  name                              = "${var.name_prefix}-ui"
  cluster                           = var.cluster_arn
  task_definition                   = aws_ecs_task_definition.ui.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  enable_execute_command            = true
  propagate_tags                    = "SERVICE"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.ui_target_group_arn
    container_name   = "ui"
    container_port   = 3000
  }

  tags = var.tags
}

resource "aws_ecs_service" "data_engine" {
  name                   = "${var.name_prefix}-data-engine"
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.data_engine.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  propagate_tags         = "SERVICE"
  wait_for_steady_state  = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  tags = var.tags
}

locals {
  scalable_services = {
    api         = aws_ecs_service.api.name
    ui          = aws_ecs_service.ui.name
    data_engine = aws_ecs_service.data_engine.name
  }
}

resource "aws_appautoscaling_target" "service" {
  for_each = local.scalable_services

  max_capacity       = var.maximum_desired_count
  min_capacity       = var.desired_count
  resource_id        = "service/${var.cluster_name}/${each.value}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = aws_appautoscaling_target.service

  name               = "${var.name_prefix}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
