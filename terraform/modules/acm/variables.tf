variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
