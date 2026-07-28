resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t4g.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/../../user-data/jenkins-slave.sh", {
    project_name = var.project_name
  })

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-jenkins-slave"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-24.04-*-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}
