variable "aws_region" {
  description = "AWS region in which to provision the EC2 instances."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile for the EC2 stack."
  type        = string
  default     = null
  nullable    = true
}

variable "subnet_id" {
  description = "Subnet ID in which to launch all five instances."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to associate with all five instances."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group ID is required."
  }
}

variable "protected_instance_name" {
  description = "Key of the one instance protected from Terraform destruction."
  type        = string
  default     = "critical-prod-01"
}

variable "instances" {
  description = "Exactly five independently configured EC2 instances keyed by their Name tag."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    key_name         = string
    environment      = string
    owner            = string
  }))

  validation {
    condition     = length(var.instances) == 5
    error_message = "Exactly five instances must be specified."
  }

  validation {
    condition     = length(distinct([for instance in values(var.instances) : instance.instance_type])) == length(var.instances)
    error_message = "Each instance must use a different instance_type."
  }

  validation {
    condition     = alltrue([for instance in values(var.instances) : contains(["gp2", "gp3", "standard"], instance.root_volume_type)])
    error_message = "Each root_volume_type must be an account-eligible root volume type: gp2, gp3, or standard."
  }

  validation {
    condition     = length(distinct([for instance in values(var.instances) : instance.root_volume_size])) == length(var.instances)
    error_message = "Each instance must use a different root_volume_size."
  }

  validation {
    condition     = alltrue([for instance in values(var.instances) : instance.root_volume_size > 0])
    error_message = "Every root_volume_size must be greater than zero."
  }

  validation {
    condition     = length(distinct([for instance in values(var.instances) : instance.key_name])) == length(var.instances)
    error_message = "Each instance must use a different key_name."
  }

  validation {
    condition     = contains(keys(var.instances), var.protected_instance_name)
    error_message = "protected_instance_name must be a key in instances."
  }

  validation {
    condition     = alltrue([for name, instance in var.instances : length(trimspace(name)) > 0 && length(trimspace(instance.environment)) > 0 && length(trimspace(instance.owner)) > 0])
    error_message = "Instance names, environment values, and owner values must not be empty."
  }
}

variable "tags" {
  description = "Additional tags applied to every EC2 instance."
  type        = map(string)
  default     = {}
}
