variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB DNS name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN (us-east-1)"
  type        = string
}
