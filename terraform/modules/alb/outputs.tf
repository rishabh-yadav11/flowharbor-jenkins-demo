output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  value = aws_lb.this.zone_id
}

output "listener_arn" {
  value = aws_lb_listener.https.arn
}

output "dev_target_group_arn" {
  value = aws_lb_target_group.dev.arn
}

output "staging_target_group_arn" {
  value = aws_lb_target_group.staging.arn
}

output "prod_target_group_arn" {
  value = aws_lb_target_group.prod.arn
}
