output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.this.private_ip}:8080"
}
