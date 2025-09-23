output "name_prefix" {
  value       = local.name_prefix
  description = "Trimmed name prefix for resource naming."
}

output "rendered_templates" {
  value       = local.rendered_templates
  description = "Map of class name to rendered manifest content."
}

output "manifest_list" {
  value       = local.manifest_list
  description = "Concatenated list of all manifests (templates and inline)."
}

output "compute_instances" {
  value       = local.compute_instances
  description = "Aggregated compute instance definitions from manifests."
}

output "networks" {
  value       = local.networks
  description = "Aggregated network definitions from manifests."
}

output "subnets" {
  value       = local.subnets
  description = "Aggregated subnet definitions from manifests."
}

output "volumes" {
  value       = local.volumes
  description = "Aggregated volume definitions from manifests."
}

output "security_groups" {
  value       = local.security_groups
  description = "Security group definitions without inline rules."
}

output "security_groups_raw" {
  value       = local.security_groups_raw
  description = "Original security group definitions including inline rules."
}

output "security_group_rules" {
  value       = local.security_group_rules
  description = "Flattened security group rules keyed by security group and rule name."
}
