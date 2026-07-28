terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_acm_certificate" "alb" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  provider                  = aws

  tags = {
    Name = "${var.domain_name}-alb-cert"
  }
}

resource "aws_acm_certificate" "cloudfront" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  provider          = aws.us_east_1

  tags = {
    Name = "${var.domain_name}-cloudfront-cert"
  }
}
