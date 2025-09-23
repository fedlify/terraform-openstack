output "compute_instances" {
  description = "Compute instances created by the web stack"
  value       = module.web_stack.compute_instance_ids
}

output "networks" {
  description = "Networks created by the web stack"
  value       = module.web_stack.network_ids
}

output "subnets" {
  description = "Subnets created by the web stack"
  value       = module.web_stack.subnet_ids
}

output "security_groups" {
  description = "Security groups created by the web stack"
  value       = module.web_stack.security_group_ids
}

output "volumes" {
  description = "Volumes created by the web stack"
  value       = module.web_stack.volume_ids
}

output "floating_ips" {
  description = "Floating IPs allocated for the web stack"
  value = {
    ids       = module.web_stack.floating_ip_ids
    addresses = module.web_stack.floating_ip_addresses
  }
}
