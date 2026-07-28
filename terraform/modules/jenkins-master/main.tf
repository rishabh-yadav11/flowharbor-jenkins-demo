resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t4g.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../../user-data/jenkins-master.sh", {
    ecr_repository_url = var.ecr_repository_url
    domain_name        = var.domain_name
    project_name       = var.project_name
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-jenkins-master"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_ssm_parameter" "jenkins_admin_password" {
  name  = "/${var.project_name}/jenkins-admin-password"
  type  = "SecureString"
  value = "pending"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jenkins_master_url" {
  name  = "/${var.project_name}/jenkins-master-url"
  type  = "String"
  value = "http://${aws_instance.this.private_ip}:8080"

  lifecycle {
    ignore_changes = [value]
  }
}
