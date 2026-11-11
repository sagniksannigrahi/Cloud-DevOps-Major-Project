variable "region" {
  description = "AWS region of the EC2 instance"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag of the EC2 instance created in the AWS console"
  type        = string
  default     = "DevOps major project"
}

variable "ssh_cidr" {
  description = "Who may SSH in. Set to your own IP (e.g. 1.2.3.4/32) to lock it down."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_key_path" {
  description = "Path to the EC2 key pair on the machine running Ansible"
  type        = string
  default     = "~/.ssh/devops-project.pem"
}
