data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  protected_instances = {
    for name, instance in var.instances : name => instance
    if name == var.protected_instance_name
  }
  standard_instances = {
    for name, instance in var.instances : name => instance
    if name != var.protected_instance_name
  }
}

resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = each.value.key_name

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? max(100, each.value.root_volume_size * 10) : null
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      Name        = each.key
      Environment = each.value.environment
      Owner       = each.value.owner
    })
  }

  tags = merge(var.tags, {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "standard" {
  for_each = local.standard_instances

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = each.value.key_name

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? max(100, each.value.root_volume_size * 10) : null
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      Name        = each.key
      Environment = each.value.environment
      Owner       = each.value.owner
    })
  }

  tags = merge(var.tags, {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  })
}
