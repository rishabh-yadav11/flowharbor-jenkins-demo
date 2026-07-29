# =============================================================================
# Route53 Module — main.tf
# =============================================================================
# This module creates DNS A records in Route53 for the FlowHarbor application.
#
# DNS records created:
#   - jenkins.flowharbor.in  → ALB (alias)
#   - testing.flowharbor.in  → ALB (alias)
#   - staging.flowharbor.in  → ALB (alias)
#   - flowharbor.in          → CloudFront (alias)
#
# All A records use Route53's alias functionality, which is free and provides
# better health-check integration than CNAME records.
# =============================================================================

# ---- Jenkins Subdomain ------------------------------------------------------
# jenkins.flowharbor.in routes to the ALB, which forwards to the Jenkins
# Master instance on port 8080.
resource "aws_route53_record" "jenkins" {
  zone_id = var.hosted_zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true   # Only route to healthy ALB targets
  }
}

# ---- Testing (Dev) Subdomain ------------------------------------------------
# testing.flowharbor.in routes to the ALB, which forwards to the dev Fargate
# service. This is the auto-deployed environment.
resource "aws_route53_record" "testing" {
  zone_id = var.hosted_zone_id
  name    = "testing.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ---- Staging Subdomain ------------------------------------------------------
# staging.flowharbor.in routes to the ALB, which forwards to the staging
# Fargate service. Requires manual approval to deploy to.
resource "aws_route53_record" "staging" {
  zone_id = var.hosted_zone_id
  name    = "staging.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ---- Root Domain (Production) -----------------------------------------------
# flowharbor.in routes to CloudFront (not directly to the ALB). CloudFront
# sits in front of the ALB to provide CDN caching, edge TLS termination, and
# DDoS protection.
resource "aws_route53_record" "root" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name           # Root domain (e.g., flowharbor.in)
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false    # CloudFront doesn't support health checks in aliases
  }
}
