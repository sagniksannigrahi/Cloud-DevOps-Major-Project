# Terraform: manages the AWS network access for the "DevOps major project" EC2 instance.
#
# - Finds the running EC2 instance by its Name tag.
# - Creates a security group (firewall) that opens SSH, the CloudSleuth app and Jenkins.
# - Attaches it to the instance.
# - Writes the Ansible inventory with the instance's current public IP.
#
# Run from infra/terraform:  terraform init && terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 6.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

provider "aws" {
  region = var.region
}

data "aws_instance" "server" {
  filter {
    name   = "tag:Name"
    values = [var.instance_name]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_security_group" "cloudsleuth" {
  name        = "cloudsleuth-devops-sg"
  description = "CloudSleuth: SSH, web app (80) and Jenkins (8080)"
  vpc_id      = data.aws_instance.server.vpc_id

  ingress {
    description = "SSH (Ansible and admin)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "CloudSleuth web app"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins UI and GitHub webhook (login required)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (apt, Docker Hub, GitHub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "cloudsleuth-devops-sg"
    Project = "Cloud-DevOps-Major-Project"
  }
}

resource "aws_network_interface_sg_attachment" "server" {
  security_group_id    = aws_security_group.cloudsleuth.id
  network_interface_id = data.aws_instance.server.network_interface_id
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content         = <<-EOT
    # The EC2 server Ansible configures. `terraform apply` rewrites this file with the
    # current public IP (it changes whenever the instance is stopped and started).
    [jenkins]
    devops-major-project ansible_host=${data.aws_instance.server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.ssh_key_path}
  EOT
}
