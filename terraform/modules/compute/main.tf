# =============================================================================
# Compute Module — palavraCadabra
# =============================================================================
# Provisions:
#   - ECS Cluster for Fargate tasks
#   - ECS Task Definition for the FastAPI backend
#   - ECS Service with desired count and deployment configuration
#   - Application Load Balancer (ALB) with target group and listeners
#   - IAM roles for ECS task execution and task role
#   - CloudWatch log group for container logs
# =============================================================================

variable "project" {
  description = "Project name for resource tagging"
  type        = string
  default     = "palavracadabra"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID for the application tier"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the API container"
  type        = string
  default     = "palavracadabra/api:latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

# --- ECS Cluster ---

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project}-${var.environment}/api"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- IAM Roles ---

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-${var.environment}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.project}-${var.environment}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- Task Definition ---

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.container_image
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_region" "current" {}

# --- ALB ---

resource "aws_lb" "api" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.app_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project}-${var.environment}-api-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.first.vpc_id
}

data "aws_subnet" "first" {
  id = var.public_subnet_ids[0]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- ECS Service ---

resource "aws_ecs_service" "api" {
  name            = "${var.project}-${var.environment}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- Outputs ---

output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "alb_dns_name" {
  value = aws_lb.api.dns_name
}

output "alb_arn" {
  value = aws_lb.api.arn
}
