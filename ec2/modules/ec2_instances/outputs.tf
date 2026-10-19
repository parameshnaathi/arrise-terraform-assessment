output "instance_ids" {
  description = "Instance IDs keyed by configured instance name."
  value = merge(
    { for name, instance in aws_instance.protected : name => instance.id },
    { for name, instance in aws_instance.standard : name => instance.id }
  )
}

output "private_ips" {
  description = "Private IP addresses keyed by configured instance name."
  value = merge(
    { for name, instance in aws_instance.protected : name => instance.private_ip },
    { for name, instance in aws_instance.standard : name => instance.private_ip }
  )
}
