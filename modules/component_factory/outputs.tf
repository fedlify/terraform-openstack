output "compute_instance_ids" {
  description = "IDs of compute instances created by the module."
  value       = { for k, v in openstack_compute_instance_v2.this : k => v.id }
}

output "network_ids" {
  description = "IDs of networks created by the module."
  value       = { for k, v in openstack_networking_network_v2.this : k => v.id }
}

output "subnet_ids" {
  description = "IDs of subnets created by the module."
  value       = { for k, v in openstack_networking_subnet_v2.this : k => v.id }
}

output "security_group_ids" {
  description = "IDs of security groups created by the module."
  value       = { for k, v in openstack_networking_secgroup_v2.this : k => v.id }
}

output "volume_ids" {
  description = "IDs of block storage volumes created by the module."
  value       = { for k, v in openstack_blockstorage_volume_v3.this : k => v.id }
}

output "floating_ip_ids" {
  description = "IDs of floating IPs allocated by the module."
  value = {
    for k, v in local.floating_ip_requests :
    k => coalesce(lookup(local.floating_ip_resource_ids, k, null), v.id)
  }
}

output "floating_ip_addresses" {
  description = "Floating IP addresses associated with compute instances."
  value = {
    for k, v in local.floating_ip_requests :
    k => coalesce(lookup(local.floating_ip_resource_addresses, k, null), v.address, v.floating_ip)
  }
}

output "manifest" {
  description = "The merged manifest after template rendering. Useful for debugging."
  value = {
    compute_instances    = local.compute_instances
    networks             = local.networks
    subnets              = local.subnets
    security_groups      = local.security_groups_raw
    volumes              = local.volumes
    security_group_rules = local.security_group_rules
    floating_ips         = local.floating_ip_requests
  }
}
