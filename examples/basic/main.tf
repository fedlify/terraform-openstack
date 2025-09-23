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

locals {
  public_key_material = var.public_key_path != "" ? trimspace(file(var.public_key_path)) : ""
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
    web = {
      template_path = "${path.module}/templates/web.yaml.tmpl"
      vars = {
        instance_name       = "${var.resource_prefix}-web"
        image_name          = var.image_name
        flavor_name         = var.flavor_name
        key_pair            = var.key_pair
        network_name        = "${var.resource_prefix}-net"
        subnet_name         = "${var.resource_prefix}-subnet"
        subnet_cidr         = var.subnet_cidr
        gateway_ip          = var.gateway_ip
        security_group      = "${var.resource_prefix}-sg"
        existing_network_id = var.existing_network_id
        existing_subnet_id  = var.existing_subnet_id
        assign_floating_ip  = var.assign_floating_ip
        floating_network_id = var.floating_network_id
        floating_ip_pool    = var.floating_ip_pool
      }
    }
  }

  resource_manifests = [
    {
      volumes = {
        data = {
          size        = 50
          name        = "data"
          volume_type = var.volume_type
        }
      }
    }
  ]
}
