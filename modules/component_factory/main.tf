module "manifest" {
  source = "./internal_manifest"

  resource_templates = var.resource_templates
  resource_manifests = var.resource_manifests
  name_prefix        = var.name_prefix
}

locals {
  name_prefix          = module.manifest.name_prefix
  compute_instances    = module.manifest.compute_instances
  networks             = module.manifest.networks
  subnets              = module.manifest.subnets
  volumes              = module.manifest.volumes
  security_groups_raw  = module.manifest.security_groups_raw
  security_groups      = module.manifest.security_groups
  security_group_rules = module.manifest.security_group_rules

  floating_ip_requests_raw = {
    for instance_key, instance_def in local.compute_instances :
    instance_key => instance_def.floating_ip
    if try(instance_def.floating_ip, null) != null
  }

  volume_attachment_entries = flatten([
    for instance_key, instance_def in local.compute_instances :
    [
      for idx, attachment in try(instance_def.attachments, []) :
      {
        key          = "${instance_key}__${idx}"
        instance_key = instance_key
        attachment   = attachment
      }
    ]
  ])

  volume_attachments = {
    for entry in local.volume_attachment_entries :
    entry.key => entry
  }
}

data "openstack_networking_network_v2" "floating" {
  for_each = toset([
    for cfg in values(local.floating_ip_requests_raw) :
    cfg.floating_network_id
    if try(cfg.floating_network_id, "") != ""
  ])

  network_id = each.value
}

locals {
  floating_network_name_lookup = {
    for id, net in data.openstack_networking_network_v2.floating :
    id => net.name
  }

  floating_ip_requests = {
    for instance_key, cfg in local.floating_ip_requests_raw :
    instance_key => merge(cfg, {
      pool = compact([
        try(cfg.pool, null),
        try(cfg.floating_ip_pool, null),
        lookup(local.floating_network_name_lookup, try(cfg.floating_network_id, ""), null)
      ])[0]
      delete_on_destroy = try(cfg.delete_on_destroy, true)
    })
    if length(compact([
      try(cfg.pool, null),
      try(cfg.floating_ip_pool, null),
      lookup(local.floating_network_name_lookup, try(cfg.floating_network_id, ""), null)
    ])) > 0
  }

  floating_ip_requests_release = {
    for k, v in local.floating_ip_requests :
    k => v if v.delete_on_destroy
  }

  floating_ip_requests_retain = {
    for k, v in local.floating_ip_requests :
    k => v if v.delete_on_destroy == false
  }
}

data "openstack_networking_port_v2" "floating_target" {
  for_each = local.floating_ip_requests

  device_id = openstack_compute_instance_v2.this[each.key].id

  depends_on = [openstack_compute_instance_v2.this]
}

resource "openstack_networking_network_v2" "this" {
  for_each = local.networks

  name = try(each.value.name, "") != "" ? each.value.name : (
    local.name_prefix != "" ? format("%s%s", local.name_prefix, each.key) : each.key
  )
  admin_state_up        = try(each.value.admin_state_up, true)
  description           = try(each.value.description, null)
  mtu                   = try(each.value.mtu, null)
  region                = try(each.value.region, null)
  external              = try(each.value.external, null)
  shared                = try(each.value.shared, null)
  tenant_id             = try(each.value.tenant_id, null)
  port_security_enabled = try(each.value.port_security_enabled, null)
  qos_policy_id         = try(each.value.qos_policy_id, null)
}

resource "openstack_networking_subnet_v2" "this" {
  for_each = local.subnets

  name = try(each.value.name, "") != "" ? each.value.name : (
    local.name_prefix != "" ? format("%s%s", local.name_prefix, each.key) : each.key
  )
  network_id = try(
    each.value.network_id,
    openstack_networking_network_v2.this[each.value.network_ref].id
  )
  cidr        = each.value.cidr
  ip_version  = try(each.value.ip_version, 4)
  gateway_ip  = try(each.value.gateway_ip, null)
  enable_dhcp = try(each.value.enable_dhcp, true)

  dns_nameservers   = try(each.value.dns_nameservers, null)
  description       = try(each.value.description, null)
  ipv6_address_mode = try(each.value.ipv6_address_mode, null)
  ipv6_ra_mode      = try(each.value.ipv6_ra_mode, null)

  dynamic "allocation_pool" {
    for_each = try(each.value.allocation_pools, [])
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}

resource "openstack_networking_secgroup_v2" "this" {
  for_each = local.security_groups

  name = try(each.value.name, "") != "" ? each.value.name : (
    local.name_prefix != "" ? format("%s%s", local.name_prefix, each.key) : each.key
  )
  description = try(each.value.description, null)
  region      = try(each.value.region, null)
  project_id  = try(each.value.project_id, null)
  tenant_id   = try(each.value.tenant_id, null)
}

resource "openstack_networking_secgroup_rule_v2" "this" {
  for_each = local.security_group_rules

  direction = each.value.direction
  ethertype = try(each.value.ethertype, "IPv4")
  protocol  = try(each.value.protocol, null)

  port_range_min   = try(each.value.port_range_min, null)
  port_range_max   = try(each.value.port_range_max, null)
  remote_ip_prefix = try(each.value.remote_ip_prefix, null)
  remote_group_id = try(
    each.value.remote_group_id,
    openstack_networking_secgroup_v2.this[each.value.remote_group_ref].id
  )
  description = try(each.value.description, null)
  region      = try(each.value.region, null)

  security_group_id = try(
    each.value.security_group_id,
    openstack_networking_secgroup_v2.this[each.value.security_group_key].id
  )
}

resource "openstack_blockstorage_volume_v3" "this" {
  for_each = local.volumes

  name = try(each.value.name, "") != "" ? each.value.name : (
    local.name_prefix != "" ? format("%s%s", local.name_prefix, each.key) : each.key
  )
  description       = try(each.value.description, null)
  size              = each.value.size
  volume_type       = try(each.value.volume_type, null)
  availability_zone = try(each.value.availability_zone, null)
  image_id          = try(each.value.image_id, null)
  snapshot_id       = try(each.value.snapshot_id, null)
  metadata          = try(each.value.metadata, null)
  source_vol_id     = try(each.value.source_vol_id, null)
}

resource "openstack_compute_instance_v2" "this" {
  for_each = local.compute_instances

  name = try(each.value.name, "") != "" ? each.value.name : (
    local.name_prefix != "" ? format("%s%s", local.name_prefix, each.key) : each.key
  )
  image_id          = try(each.value.image_id, null)
  image_name        = try(each.value.image_name, null)
  flavor_id         = try(each.value.flavor_id, null)
  flavor_name       = try(each.value.flavor_name, null)
  key_pair          = try(each.value.key_pair, null)
  availability_zone = try(each.value.availability_zone, null)
  security_groups   = try(each.value.security_groups, null)
  user_data         = try(each.value.user_data, null)
  config_drive      = try(each.value.config_drive, null)
  metadata          = try(each.value.metadata, null)

  dynamic "scheduler_hints" {
    for_each = length(keys(try(each.value.scheduler_hints, {}))) > 0 ? [each.value.scheduler_hints] : []
    content {
      group              = try(scheduler_hints.value.group, null)
      different_host     = try(scheduler_hints.value.different_host, null)
      same_host          = try(scheduler_hints.value.same_host, null)
      query              = try(scheduler_hints.value.query, null)
      target_cell        = try(scheduler_hints.value.target_cell, null)
      build_near_host_ip = try(scheduler_hints.value.build_near_host_ip, null)
    }
  }

  dynamic "network" {
    for_each = try(each.value.networks, [])
    content {
      name        = try(network.value.name, null)
      uuid        = try(network.value.uuid, null)
      port        = try(network.value.port, null)
      fixed_ip_v4 = try(network.value.fixed_ip_v4, null)
      fixed_ip_v6 = try(network.value.fixed_ip_v6, null)
    }
  }

  dynamic "block_device" {
    for_each = try(each.value.block_devices, [])
    content {
      uuid                  = try(block_device.value.uuid, null)
      source_type           = try(block_device.value.source_type, null)
      destination_type      = try(block_device.value.destination_type, null)
      boot_index            = try(block_device.value.boot_index, null)
      volume_size           = try(block_device.value.volume_size, null)
      delete_on_termination = try(block_device.value.delete_on_termination, null)
    }
  }

  dynamic "personality" {
    for_each = try(each.value.personalities, [])
    content {
      file    = personality.value.file
      content = personality.value.content
    }
  }
}

resource "openstack_networking_floatingip_v2" "release" {
  for_each = local.floating_ip_requests_release

  pool        = each.value.pool
  description = try(each.value.description, null)
  region      = try(each.value.region, null)
  tenant_id   = try(each.value.tenant_id, null)

  port_id = try(coalesce(
    try(each.value.port_id, null),
    try(each.value.port, null),
    try(each.value.port_uuid, null),
    try(openstack_compute_instance_v2.this[each.key].network[0].port, null),
    try(data.openstack_networking_port_v2.floating_target[each.key].id, null)
  ), null)
}

resource "openstack_networking_floatingip_v2" "retain" {
  for_each = local.floating_ip_requests_retain

  pool        = each.value.pool
  description = try(each.value.description, null)
  region      = try(each.value.region, null)
  tenant_id   = try(each.value.tenant_id, null)

  port_id = try(coalesce(
    try(each.value.port_id, null),
    try(each.value.port, null),
    try(each.value.port_uuid, null),
    try(openstack_compute_instance_v2.this[each.key].network[0].port, null),
    try(data.openstack_networking_port_v2.floating_target[each.key].id, null)
  ), null)

  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_compute_volume_attach_v2" "this" {
  for_each = local.volume_attachments

  instance_id = openstack_compute_instance_v2.this[each.value.instance_key].id
  volume_id = coalesce(
    try(each.value.attachment.volume_id, null),
    try(openstack_blockstorage_volume_v3.this[each.value.attachment.volume_key].id, null)
  )
  device = try(each.value.attachment.device, null)
}

locals {
  floating_ip_resource_ids = merge(
    { for k, v in openstack_networking_floatingip_v2.release : k => v.id },
    { for k, v in openstack_networking_floatingip_v2.retain : k => v.id }
  )

  floating_ip_resource_addresses = merge(
    { for k, v in openstack_networking_floatingip_v2.release : k => v.address },
    { for k, v in openstack_networking_floatingip_v2.retain : k => v.address }
  )
}
