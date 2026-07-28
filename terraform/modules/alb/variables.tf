variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for ALB"
  type        = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "jenkins_target_ip" {
  description = "Jenkins Master private IP"
  type        = string
}


