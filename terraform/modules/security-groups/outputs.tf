output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "jenkins_master_sg_id" {
  value = aws_security_group.jenkins_master.id
}

output "jenkins_slave_sg_id" {
  value = aws_security_group.jenkins_slave.id
}

output "ecs_tasks_sg_id" {
  value = aws_security_group.ecs_tasks.id
}
