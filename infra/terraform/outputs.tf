output "instance_id" {
  value = data.aws_instance.server.id
}

output "public_ip" {
  value = data.aws_instance.server.public_ip
}

output "app_url" {
  value = "http://${data.aws_instance.server.public_ip}/"
}

output "jenkins_url" {
  value = "http://${data.aws_instance.server.public_ip}:8080/"
}

output "security_group_id" {
  value = aws_security_group.cloudsleuth.id
}
