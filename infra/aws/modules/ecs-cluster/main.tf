resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "${var.name_prefix}.internal"
  vpc  = var.vpc_id
  tags = var.tags
}

resource "aws_security_group" "tasks" {
  name_prefix = "${var.name_prefix}-tasks-"
  description = "ECS task ingress from the ALB and peer application tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "API from load balancer"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.load_balancer_security_group_id]
  }

  ingress {
    description     = "UI from load balancer"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.load_balancer_security_group_id]
  }

  ingress {
    description = "AMQP between application tasks"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tasks" })

  lifecycle {
    create_before_destroy = true
  }
}
