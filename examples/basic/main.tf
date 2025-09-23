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
  }

  instance_blueprints = {
    web = {
      instance_key       = "web"
      instance_name      = "${var.resource_prefix}-web"
      security_group_key = "web"
      security_group     = "${var.resource_prefix}-web-sg"
      # network_key stays required – the manifest template references it for map keys even when reusing an existing network
      network_key        = "main"
      subnet_key         = "main"
      attachments_json = jsonencode([
        {
          volume_key = "web_data"
          device     = var.data_volume_device
        }
      ])
    }
    api = {
      instance_key            = "api"
      instance_name           = "${var.resource_prefix}-api"
      security_group_key      = "api"
      security_group          = "${var.resource_prefix}-api-sg"
      # network_key stays required – the manifest template references it for map keys even when reusing an existing network
      network_key             = "main"
      subnet_key              = "main"
      render_network_manifest = false
      attachments_json = jsonencode([
        {
          volume_key = "api_data"
          device     = var.data_volume_device
        }
      ])
    }
  }
}

resource "openstack_compute_keypair_v2" "example" {
  count = var.public_key_path != "" ? 1 : 0

  name       = var.key_pair
  public_key = local.public_key_material
}

module "web_stack" {
  source = "../../modules/component_factory"

  name_prefix = var.resource_prefix

  resource_templates = {
    for key, cfg in local.instance_blueprints :
    key => {
      template_path = "${path.module}/templates/web.yaml.tmpl"
      vars          = merge(local.template_base_vars, cfg)
    }
  }

  resource_manifests = [
    {
      volumes = {
        web_data = {
          size        = var.data_volume_size
          name        = "${var.resource_prefix}-web-data"
          volume_type = var.volume_type
        }

        api_data = {
          size        = var.data_volume_size
          name        = "${var.resource_prefix}-api-data"
          volume_type = var.volume_type
        }
      }
    }
  ]
}
