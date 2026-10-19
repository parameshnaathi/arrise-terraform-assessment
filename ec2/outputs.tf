output "instance_ids" {
  description = "EC2 instance IDs indexed by their Name tag."
  value       = module.ec2_instances.instance_ids
}

output "private_ips" {
  description = "Private IP addresses indexed by their Name tag."
  value       = module.ec2_instances.private_ips
}
