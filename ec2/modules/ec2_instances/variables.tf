variable "instances" {
  description = "All instances to provision, keyed by their Name tag."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    key_name         = string
    environment      = string
    owner            = string
  }))
}

variable "subnet_id" {
  description = "Subnet in which to launch the EC2 instances."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to the EC2 instances."
  type        = list(string)
}

variable "protected_instance_name" {
  description = "Instance map key receiving the prevent_destroy lifecycle rule."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to each instance and root volume."
  type        = map(string)
  default     = {}
}
