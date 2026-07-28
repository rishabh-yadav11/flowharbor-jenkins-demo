output "alb_certificate_arn" {
  value = aws_acm_certificate.alb.arn
}

output "cloudfront_certificate_arn" {
  value = aws_acm_certificate.cloudfront.arn
}

output "alb_validation_records" {
  value = aws_acm_certificate.alb.domain_validation_options
}

output "cloudfront_validation_records" {
  value = aws_acm_certificate.cloudfront.domain_validation_options
}
