variable "project_name" {
  description = "Project name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "ecs_task_sg_id" {
  description = "ECS tasks security group ID"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "alb_dev_tg_arn" {
  description = "ALB dev target group ARN"
  type        = string
}

variable "alb_staging_tg_arn" {
  description = "ALB staging target group ARN"
  type        = string
}

variable "alb_prod_tg_arn" {
  description = "ALB prod target group ARN"
  type        = string
}
