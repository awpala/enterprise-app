resource "aws_security_group" "efs" {
  name_prefix = "${var.name_prefix}-rabbitmq-efs-"
  description = "NFS ingress from RabbitMQ ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.task_security_group_id]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-rabbitmq-efs" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_efs_file_system" "this" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags             = merge(var.tags, { Name = "${var.name_prefix}-rabbitmq" })
}

resource "aws_efs_mount_target" "this" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "rabbitmq" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 999
    uid = 999
  }

  root_directory {
    path = "/rabbitmq"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "0750"
    }
  }

  tags = var.tags
}

resource "aws_service_discovery_service" "this" {
  name = "rabbitmq"

  dns_config {
    namespace_id   = var.namespace_id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-rabbitmq"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name = "rabbitmq-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.rabbitmq.id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = var.image
      essential = true
      portMappings = [
        { containerPort = 5672, hostPort = 5672, protocol = "tcp" },
        { containerPort = 15672, hostPort = 15672, protocol = "tcp" },
      ]
      environment = [
        { name = "RABBITMQ_DEFAULT_USER", value = var.username },
      ]
      secrets = [
        { name = "RABBITMQ_DEFAULT_PASS", valueFrom = var.password_secret_arn },
      ]
      mountPoints = [
        { sourceVolume = "rabbitmq-data", containerPath = "/var/lib/rabbitmq", readOnly = false },
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "rabbitmq-diagnostics -q ping || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "rabbitmq"
        }
      }
    },
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                   = "${var.name_prefix}-rabbitmq"
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true
  propagate_tags         = "SERVICE"
  wait_for_steady_state  = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  depends_on = [aws_efs_mount_target.this]
  tags       = var.tags
}
