output "jenkins_record" {
  value = aws_route53_record.jenkins.name
}

output "testing_record" {
  value = aws_route53_record.testing.name
}

output "staging_record" {
  value = aws_route53_record.staging.name
}

output "root_record" {
  value = aws_route53_record.root.name
}
