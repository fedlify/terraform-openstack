variable "auth_url" {
  description = "OpenStack identity endpoint (ignored when cloud_name is set)"
  type        = string
  default     = ""
}

variable "cloud_name" {
  description = "Named cloud from clouds.yaml to use when configuring the provider"
  type        = string
  default     = ""

  validation {
    condition = var.cloud_name != "" || (
      var.auth_url != "" &&
      var.project_name != "" &&
      var.username != "" &&
      var.password != ""
    )
    error_message = "Provide cloud_name for clouds.yaml auth or supply auth_url, project_name, username, and password."
  }
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

variable "domain_name" {
  description = "OpenStack domain name"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project (tenant) name"
  type        = string
  default     = ""
}

variable "username" {
  description = "User name"
  type        = string
  default     = ""
}

variable "password" {
  description = "User password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "image_name" {
  description = "Image name used by the example compute instance"
  type        = string
}

variable "image_id" {
  description = "Optional image ID; when set, bypasses the name lookup"
  type        = string
  default     = ""
}

variable "flavor_name" {
  description = "Flavor name used by the example compute instance"
  type        = string
}

variable "key_pair" {
  description = "Existing key pair to inject into the example compute instance"
  type        = string
}

variable "additional_security_groups" {
  description = "List of existing security group names to attach to the instance"
  type        = list(string)
  default     = []
}

variable "resource_prefix" {
  description = "Prefix applied to resources for the example"
  type        = string
  default     = "demo"
}

variable "subnet_cidr" {
  description = "CIDR for the example subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "gateway_ip" {
  description = "Gateway IP for the example subnet"
  type        = string
  default     = "10.10.0.1"
}

variable "volume_type" {
  description = "Optional volume type for the data volume"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the boot volume (GiB) created from the image"
  type        = number
  default     = 40
}

variable "root_volume_delete_on_termination" {
  description = "Whether to delete the boot volume when the instance is destroyed"
  type        = bool
  default     = true
}

variable "data_volume_size" {
  description = "Size of the data volumes attached to each instance"
  type        = number
  default     = 50
}

variable "data_volume_device" {
  description = "Device path used when attaching the data volume"
  type        = string
  default     = "/dev/vdb"
}

variable "format_data_volume" {
  description = "Whether to format and mount the data volume via cloud-init"
  type        = bool
  default     = false
}

variable "data_volume_filesystem" {
  description = "Filesystem type to create on the data volume when formatting"
  type        = string
  default     = "ext4"
}

variable "data_volume_mount_path" {
  description = "Mount point for the data volume when formatting is enabled"
  type        = string
  default     = "/mnt/data"
}

variable "existing_network_id" {
  description = "Reuse an existing Neutron network by ID; leave blank to create a new one"
  type        = string
  default     = ""
}

variable "existing_network_name" {
  description = "Reuse an existing Neutron network by name when ID is not supplied"
  type        = string
  default     = ""
}

variable "existing_subnet_id" {
  description = "Reuse an existing subnet by ID; leave blank to create a new one"
  type        = string
  default     = ""

  validation {
    condition     = var.existing_subnet_id == "" || var.existing_network_id != ""
    error_message = "existing_subnet_id requires existing_network_id to be set as well."
  }
}

variable "public_key_path" {
  description = "Path to an SSH public key to upload as an OpenStack key pair"
  type        = string
  default     = ""
}

variable "assign_floating_ip" {
  description = "Whether to allocate and attach a floating IP to the example instance"
  type        = bool
  default     = false

  validation {
    condition     = !var.assign_floating_ip || (var.floating_network_id != "" || var.floating_ip_pool != "")
    error_message = "When assign_floating_ip is true, provide floating_network_id or floating_ip_pool."
  }
}

variable "floating_network_id" {
  description = "External network ID used when assigning a floating IP"
  type        = string
  default     = ""
}

variable "floating_ip_pool" {
  description = "Optional pool name used when allocating a floating IP"
  type        = string
  default     = ""
}

variable "floating_ip_release_on_destroy" {
  description = "Release floating IPs when destroying the stack"
  type        = bool
  default     = true
}
