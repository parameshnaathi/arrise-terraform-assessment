module "ec2_instances" {
  source = "./modules/ec2_instances"

  instances               = var.instances
  subnet_id               = var.subnet_id
  security_group_ids      = var.security_group_ids
  protected_instance_name = var.protected_instance_name
  tags                    = var.tags
}
