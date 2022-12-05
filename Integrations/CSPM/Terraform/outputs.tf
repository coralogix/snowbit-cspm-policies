output "vpc" {
  value = data.aws_subnet.subnet.vpc_id
}
output "subnet" {
  value = var.Subnet_ID
}
output "selected-cronjob" {
  value = var.cronjob
}
output "instance-type" {
  value = aws_instance.cspm-instance.instance_type
}
output "user-added-tags" {
  value = var.additional_tags
}
output "Ingress-SSH-IP-address" {
  value = var.SSHIpAddress
}
output "Application-Name" {
  value = var.applicationName
}
output "Subsystem-Name" {
  value = var.subsystemName
}
