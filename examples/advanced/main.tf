terraform {
  required_version = ">= 1.4.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.52.1"
    }
  }
}

provider "openstack" {
  cloud       = var.cloud_name != "" ? var.cloud_name : null
  auth_url    = var.cloud_name == "" ? var.auth_url : null
  region      = var.region != "" ? var.region : null
  domain_name = var.cloud_name == "" ? var.domain_name : null
  tenant_name = var.cloud_name == "" ? var.project_name : null
  user_name   = var.cloud_name == "" ? var.username : null
  password    = var.cloud_name == "" ? var.password : null
}

data "openstack_images_image_v2" "selected" {
  count       = var.image_id == "" ? 1 : 0
  name        = var.image_name
  most_recent = true
}

locals {
  use_existing_network = var.existing_network_id != "" || var.existing_network_name != ""
}

data "openstack_networking_network_v2" "existing" {
  count = local.use_existing_network && var.existing_network_id == "" ? 1 : 0

  name = var.existing_network_name
}

locals {
  public_key_material = var.public_key_path != "" ? trimspace(file(var.public_key_path)) : ""
  selected_image_id   = var.image_id != "" ? var.image_id : data.openstack_images_image_v2.selected[0].id
  selected_network_id = local.use_existing_network ? (
    var.existing_network_id != "" ? var.existing_network_id : data.openstack_networking_network_v2.existing[0].id
  ) : ""

  instance_keys_sorted = sort(keys(var.instances))
  primary_instance_key = length(local.instance_keys_sorted) > 0 ? local.instance_keys_sorted[0] : null

  template_base_vars = {
    image_name                        = var.image_name
    image_id                          = local.selected_image_id
    flavor_name                       = var.flavor_name
    key_pair                          = var.key_pair
    network_name                      = "${var.resource_prefix}-net"
    subnet_name                       = "${var.resource_prefix}-subnet"
    subnet_cidr                       = var.subnet_cidr
    gateway_ip                        = var.gateway_ip
    existing_network_id               = local.selected_network_id
    existing_subnet_id                = var.existing_subnet_id
    assign_floating_ip                = var.assign_floating_ip
    floating_network_id               = var.floating_network_id
    floating_ip_pool                  = var.floating_ip_pool
    floating_ip_release_on_destroy    = var.floating_ip_release_on_destroy
    additional_security_groups_json   = jsonencode(var.additional_security_groups)
    root_volume_size                  = var.root_volume_size
    root_volume_delete_on_termination = var.root_volume_delete_on_termination
    data_volume_device                = var.data_volume_device
    format_data_volume                = var.format_data_volume
    data_volume_filesystem            = var.data_volume_filesystem
    data_volume_mount_path            = var.data_volume_mount_path
    render_network_manifest           = !local.use_existing_network
    attachments_json                  = jsonencode([])
    metadata_json                     = jsonencode({ role = "default" })
    block_devices_json                = jsonencode([])
  }

  instance_root_volume_requests = {
    for instance_key, instance_cfg in var.instances :
    instance_key => instance_cfg.root_volume
    if try(instance_cfg.root_volume, null) != null
  }

  instance_root_volume_keys = {
    for instance_key, _ in local.instance_root_volume_requests :
    instance_key => "root__${instance_key}"
  }

  manifest_root_volumes = {
    for instance_key, volume_cfg in local.instance_root_volume_requests :
    local.instance_root_volume_keys[instance_key] => {
      size = coalesce(
        try(volume_cfg.size, null),
        var.root_volume_size
      )
      name = (
        can(trimspace(volume_cfg.name)) && trimspace(volume_cfg.name) != ""
      ) ? trimspace(volume_cfg.name) : "${var.resource_prefix}-${instance_key}-root"
      volume_type = (
        can(trimspace(volume_cfg.volume_type)) && trimspace(volume_cfg.volume_type) != ""
      ) ? trimspace(volume_cfg.volume_type) : (var.volume_type != "" ? var.volume_type : null)
      availability_zone = try(volume_cfg.availability_zone, null)
      description       = try(volume_cfg.description, null)
      metadata          = try(volume_cfg.metadata, null)
      image_id          = local.selected_image_id
    }
  }

  instance_block_devices = {
    for instance_key, instance_cfg in var.instances :
    instance_key => (
      lookup(local.instance_root_volume_keys, instance_key, null) != null
      ? [
        {
          source_type      = "volume"
          destination_type = "volume"
          volume_key       = lookup(local.instance_root_volume_keys, instance_key, null)
          boot_index       = 0
          delete_on_termination = coalesce(
            try(instance_cfg.root_volume.delete_on_termination, null),
            var.root_volume_delete_on_termination
          )
        }
      ]
      : (
        var.root_volume_size > 0
        ? [
          {
            source_type           = "image"
            destination_type      = "volume"
            uuid                  = local.selected_image_id
            volume_size           = var.root_volume_size
            boot_index            = 0
            delete_on_termination = var.root_volume_delete_on_termination
          }
        ]
        : []
      )
    )
  }

  instance_blueprints = {
    for instance_key, instance_cfg in var.instances :
    instance_key => {
      instance_key = instance_key
      instance_name = coalesce(
        try(trimspace(instance_cfg.name), "") != "" ? trimspace(instance_cfg.name) : null,
        "${var.resource_prefix}-${instance_key}"
      )
      security_group_key = coalesce(
        try(trimspace(instance_cfg.security_group_key), "") != "" ? trimspace(instance_cfg.security_group_key) : null,
        instance_key
      )
      security_group = coalesce(
        try(trimspace(instance_cfg.security_group_name), "") != "" ? trimspace(instance_cfg.security_group_name) : null,
        "${var.resource_prefix}-${instance_key}-sg"
      )
      network_key = coalesce(
        try(trimspace(instance_cfg.network_key), "") != "" ? trimspace(instance_cfg.network_key) : null,
        "main"
      )
      subnet_key = coalesce(
        try(trimspace(instance_cfg.subnet_key), "") != "" ? trimspace(instance_cfg.subnet_key) : null,
        "main"
      )
      render_network_manifest = coalesce(
        try(instance_cfg.render_network_manifest, null),
        !local.use_existing_network && instance_key == local.primary_instance_key
      )
      attachments_json = jsonencode([
        for attachment in coalesce(try(instance_cfg.attachments, null), []) : merge(
          {
            volume_key = attachment.volume_key
          },
          coalesce(
            try(trimspace(attachment.device), "") != "" ? { device = trimspace(attachment.device) } : null,
            {}
          )
        )
      ])
      additional_security_groups_json = jsonencode(distinct(concat(
        var.additional_security_groups,
        coalesce(try(instance_cfg.additional_security_groups, null), [])
      )))
      metadata_json = jsonencode(merge(
        {
          role = coalesce(
            try(trimspace(instance_cfg.role), "") != "" ? trimspace(instance_cfg.role) : null,
            instance_key
          )
        },
        coalesce(try(instance_cfg.metadata, null), {})
      ))
      block_devices_json = jsonencode(lookup(local.instance_block_devices, instance_key, []))
    }
  }

  declared_volumes = {
    for volume_key, volume_cfg in var.volumes :
    volume_key => {
      size = volume_cfg.size
      name = (
        can(trimspace(volume_cfg.name)) && trimspace(volume_cfg.name) != ""
      ) ? trimspace(volume_cfg.name) : "${var.resource_prefix}-${volume_key}"
      volume_type = (
        can(trimspace(volume_cfg.volume_type)) && trimspace(volume_cfg.volume_type) != ""
      ) ? trimspace(volume_cfg.volume_type) : (var.volume_type != "" ? var.volume_type : null)
      availability_zone = try(volume_cfg.availability_zone, null)
      description       = try(volume_cfg.description, null)
      metadata          = try(volume_cfg.metadata, null)
      image_id          = try(volume_cfg.image_id, null)
      snapshot_id       = try(volume_cfg.snapshot_id, null)
      source_vol_id     = try(volume_cfg.source_vol_id, null)
    }
  }

  manifest_volumes = merge(local.declared_volumes, local.manifest_root_volumes)

  resource_manifests = length(local.manifest_volumes) > 0 ? [
    {
      volumes = local.manifest_volumes
    }
  ] : []
}

resource "openstack_compute_keypair_v2" "example" {
  count = var.public_key_path != "" ? 1 : 0

  name       = var.key_pair
  public_key = local.public_key_material
}

module "advanced_stack" {
  source = "../../modules/component_factory"

  name_prefix = var.resource_prefix

  resource_templates = {
    for key, cfg in local.instance_blueprints :
    key => {
      template_path = "${path.module}/templates/instance.yaml.tmpl"
      vars          = merge(local.template_base_vars, cfg)
    }
  }

  resource_manifests = local.resource_manifests
}
