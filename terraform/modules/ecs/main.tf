resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

locals {
  container_base = {
    name  = "nginx"
    image = "nginx:alpine"
    essential = true
    portMappings = [
      {
        containerPort = 80
        protocol      = "tcp"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "nginx"
      }
    }
  }
}

resource "aws_ecs_task_definition" "dev" {
  family                   = "${var.project_name}-dev"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.container_base, {
      image = "${var.ecr_repository_url}:latest"
      logConfiguration = merge(local.container_base.logConfiguration, {
        options = merge(local.container_base.logConfiguration.options, {
          "awslogs-group" = "/ecs/${var.project_name}-dev"
        })
      })
      environment = [
        { name = "ENV", value = "dev" },
        { name = "VERSION", value = "1.0.0" },
        { name = "BUILD_NUMBER", value = "0" },
        { name = "GIT_COMMIT", value = "none" },
        { name = "GIT_BRANCH", value = "none" },
        { name = "GIT_AUTHOR", value = "none" },
        { name = "TIMESTAMP", value = "none" },
        { name = "PIPELINE_URL", value = "none" }
      ]
    })
  ])

  tags = {
    Name = "${var.project_name}-dev"
  }
}

resource "aws_ecs_task_definition" "staging" {
  family                   = "${var.project_name}-staging"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.container_base, {
      image = "${var.ecr_repository_url}:latest"
      logConfiguration = merge(local.container_base.logConfiguration, {
        options = merge(local.container_base.logConfiguration.options, {
          "awslogs-group" = "/ecs/${var.project_name}-staging"
        })
      })
      environment = [
        { name = "ENV", value = "staging" },
        { name = "VERSION", value = "1.0.0" },
        { name = "BUILD_NUMBER", value = "0" },
        { name = "GIT_COMMIT", value = "none" },
        { name = "GIT_BRANCH", value = "none" },
        { name = "GIT_AUTHOR", value = "none" },
        { name = "TIMESTAMP", value = "none" },
        { name = "PIPELINE_URL", value = "none" }
      ]
    })
  ])

  tags = {
    Name = "${var.project_name}-staging"
  }
}

resource "aws_ecs_task_definition" "prod" {
  family                   = "${var.project_name}-prod"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.container_base, {
      image = "${var.ecr_repository_url}:latest"
      logConfiguration = merge(local.container_base.logConfiguration, {
        options = merge(local.container_base.logConfiguration.options, {
          "awslogs-group" = "/ecs/${var.project_name}-prod"
        })
      })
      environment = [
        { name = "ENV", value = "prod" },
        { name = "VERSION", value = "1.0.0" },
        { name = "BUILD_NUMBER", value = "0" },
        { name = "GIT_COMMIT", value = "none" },
        { name = "GIT_BRANCH", value = "none" },
        { name = "GIT_AUTHOR", value = "none" },
        { name = "TIMESTAMP", value = "none" },
        { name = "PIPELINE_URL", value = "none" }
      ]
    })
  ])

  tags = {
    Name = "${var.project_name}-prod"
  }
}

resource "aws_ecs_service" "dev" {
  name            = "${var.project_name}-dev"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.dev.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_task_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_dev_tg_arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_ecs_service" "staging" {
  name            = "${var.project_name}-staging"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.staging.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_task_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_staging_tg_arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_ecs_service" "prod" {
  name            = "${var.project_name}-prod"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prod.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_task_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_prod_tg_arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_cloudwatch_log_group" "dev" {
  name = "/ecs/${var.project_name}-dev"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "staging" {
  name = "/ecs/${var.project_name}-staging"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "prod" {
  name = "/ecs/${var.project_name}-prod"
  retention_in_days = 7
}

data "aws_region" "current" {}
