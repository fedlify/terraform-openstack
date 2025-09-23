locals {
  name_prefix = trimspace(var.name_prefix)

  rendered_templates = {
    for class_name, cfg in var.resource_templates :
    class_name => yamldecode(templatefile(cfg.template_path, lookup(cfg, "vars", {})))
  }

  manifest_list = concat(
    values(local.rendered_templates),
    var.resource_manifests
  )

  compute_instance_pairs = flatten([
    for manifest in local.manifest_list :
    [
      for key, value in try(manifest.compute_instances, {}) :
      {
        key   = key
        value = value
      }
    ]
  ])

  compute_instances = {
    for item in local.compute_instance_pairs :
    item.key => item.value
  }

  network_pairs = flatten([
    for manifest in local.manifest_list :
    [
      for key, value in try(manifest.networks, {}) :
      {
        key   = key
        value = value
      }
    ]
  ])

  networks = {
    for item in local.network_pairs :
    item.key => item.value
  }

  subnet_pairs = flatten([
    for manifest in local.manifest_list :
    [
      for key, value in try(manifest.subnets, {}) :
      {
        key   = key
        value = value
      }
    ]
  ])

  subnets = {
    for item in local.subnet_pairs :
    item.key => item.value
  }

  volume_pairs = flatten([
    for manifest in local.manifest_list :
    [
      for key, value in try(manifest.volumes, {}) :
      {
        key   = key
        value = value
      }
    ]
  ])

  volumes = {
    for item in local.volume_pairs :
    item.key => item.value
  }

  security_group_pairs = flatten([
    for manifest in local.manifest_list :
    [
      for key, value in try(manifest.security_groups, {}) :
      {
        key   = key
        value = value
      }
    ]
  ])

  security_groups_raw = {
    for item in local.security_group_pairs :
    item.key => item.value
  }

  security_groups = {
    for sg_key, sg_def in local.security_groups_raw :
    sg_key => { for attr_key, attr_value in sg_def : attr_key => attr_value if attr_key != "rules" }
  }

  security_group_rule_entries = flatten([
    for sg_key, sg_def in local.security_groups_raw :
    [
      for rule_key, rule_def in try(sg_def.rules, {}) :
      {
        key                = "${sg_key}__${rule_key}"
        security_group_key = sg_key
        rule               = rule_def
      }
    ]
  ])

  security_group_rules = {
    for entry in local.security_group_rule_entries :
    entry.key => merge(entry.rule, {
      security_group_key = entry.security_group_key
    })
  }
}
