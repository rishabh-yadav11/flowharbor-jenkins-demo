variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB zone ID"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_zone_id" {
  description = "CloudFront hosted zone ID"
  type        = string
}

variable "acm_alb_validation_records" {
  description = "ACM ALB certificate validation records"
  type        = list(any)
}

variable "acm_cf_validation_records" {
  description = "ACM CloudFront certificate validation records"
  type        = list(any)
}
