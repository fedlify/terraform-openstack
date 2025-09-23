terraform {
  required_version = ">= 1.4.0"
}

locals {
  template_vars_base = {
    image_name                        = "ubuntu-22.04"
    image_id                          = "test-image-id"
    flavor_name                       = "m1.small"
    key_pair                          = "test-key"
    network_name                      = "test-net"
    subnet_name                       = "test-subnet"
    subnet_cidr                       = "10.10.0.0/24"
    gateway_ip                        = "10.10.0.1"
    existing_network_id               = ""
    existing_subnet_id                = ""
    assign_floating_ip                = false
    floating_network_id               = ""
    floating_ip_pool                  = ""
    floating_ip_release_on_destroy    = true
    additional_security_groups_json   = jsonencode([])
    root_volume_size                  = 20
    root_volume_delete_on_termination = true
    data_volume_device                = "/dev/vdb"
    format_data_volume                = false
    data_volume_filesystem            = "ext4"
    data_volume_mount_path            = "/mnt/data"
    render_network_manifest           = true
    attachments_json                  = jsonencode([])
  }

  template_vars = merge(local.template_vars_base, {
    instance_key       = "web"
    instance_name      = "test-web"
    security_group_key = "web"
    security_group     = "test-sg"
    network_key        = "main"
    subnet_key         = "main"
  })
}

module "manifest_engine" {
  source = "../../modules/component_factory/internal_manifest"

  name_prefix = "test-"

  resource_templates = {
    web = {
      template_path = "${path.module}/../../examples/basic/templates/web.yaml.tmpl"
      vars          = local.template_vars
    }
  }

  resource_manifests = [
    {
      volumes = {
        extra = {
          size = 5
          name = "extra"
        }
      }
    }
  ]
}

output "manifest" {
  value = {
    compute_instances    = module.manifest_engine.compute_instances
    networks             = module.manifest_engine.networks
    subnets              = module.manifest_engine.subnets
    volumes              = module.manifest_engine.volumes
    security_groups      = module.manifest_engine.security_groups_raw
    security_group_rules = module.manifest_engine.security_group_rules
  }
}
