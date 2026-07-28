output "jenkins_url" {
  description = "Jenkins UI URL"
  value       = "https://jenkins.${var.domain_name}"
}

output "testing_url" {
  description = "Testing (dev) environment URL"
  value       = "https://testing.${var.domain_name}"
}

output "staging_url" {
  description = "Staging environment URL"
  value       = "https://staging.${var.domain_name}"
}

output "production_url" {
  description = "Production environment URL"
  value       = "https://${var.domain_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "jenkins_admin_password_command" {
  description = "Command to retrieve Jenkins admin password from SSM"
  value       = "aws ssm get-parameter --name /${var.project_name}/jenkins-admin-password --with-decryption --query Parameter.Value --output text"
}

output "jenkins_master_instance_id" {
  description = "Jenkins Master EC2 instance ID"
  value       = module.jenkins_master.instance_id
}

output "jenkins_slave_instance_id" {
  description = "Jenkins Slave EC2 instance ID"
  value       = module.jenkins_slave.instance_id
}
