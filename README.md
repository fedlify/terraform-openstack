# terraform-openstack

Composable Terraform tooling for OpenStack that turns declarative manifests into concrete networks, subnets, security groups, volumes, and compute instances. The repository centres on the `component_factory` module, which lets you keep your infrastructure blueprints as reusable YAML templates (`templatefile`) or inline Terraform maps. Repository home: https://github.com/fedlify/terraform-openstack

## Why component_factory?
- Keep infrastructure definitions in manifest form and reuse them across environments.
- Mix template-driven manifests with inline overrides in a single module call.
- Create only the resource classes you need—omit network blocks to target existing Neutron networks.
- Obtain a merged manifest as an output for debugging or feeding into other tooling.

## Requirements
- Terraform `>= 1.4.0`.
- `terraform-provider-openstack/openstack >= 1.52.1`.
- OpenStack project credentials or a `clouds.yaml` entry accessible to Terraform.

## Repository layout
- `modules/component_factory` – reusable module that materialises manifests.
- `examples/basic` – starter configuration showing templated instances, optional floating IPs, and reusing an existing network.
- `tests` – Go-based assertions exercising the manifest engine without contacting OpenStack.

## How the module works
`component_factory` accepts two sources of manifests:

1. **`resource_templates`** – map of template definitions keyed by a class name. Each entry specifies a `template_path` and optional `vars`. Terraform renders the template with `templatefile`, decodes the YAML, and merges it into the manifest.
2. **`resource_manifests`** – list of already-rendered manifest maps for ad-hoc or environment-specific overrides.

Everything is merged into a single manifest (networks, subnets, security groups, volumes, compute instances, floating IP requests). Resources are created with `for_each`, so omitting a section means no resources of that type are instantiated.

## Usage

### 1. Declare the module
```hcl
module "stack" {
  source = "github.com/fedlify/terraform-openstack//modules/component_factory"

  name_prefix = "demo-"

  resource_templates = {
    web = {
      template_path = "${path.module}/templates/web.yaml.tmpl"
      vars = {
        instance_key       = "web"
        instance_name      = "demo-web"
        image_name         = "ubuntu-22.04"
        flavor_name        = "m1.small"
        key_pair           = "existing-key"
        security_group_key = "web"
        security_group     = "demo-web-sg"
        network_key        = "main"
        subnet_key         = "main"
        subnet_cidr        = "10.10.0.0/24"
        gateway_ip         = "10.10.0.1"
        render_network_manifest = true
      }
    }
  }

  resource_manifests = [
    {
      volumes = {
        data = {
          size = 50
          name = "demo-data"
        }
      }
    }
  ]
}
```

### 2. Configure the OpenStack provider
Use a `clouds.yaml` entry or explicit credentials. The example below switches between both patterns based on `cloud_name`:

```hcl
provider "openstack" {
  cloud       = var.cloud_name != "" ? var.cloud_name : null
  auth_url    = var.cloud_name == "" ? var.auth_url : null
  region      = var.region
  domain_name = var.cloud_name == "" ? var.domain_name : null
  tenant_name = var.cloud_name == "" ? var.project_name : null
  user_name   = var.cloud_name == "" ? var.username : null
  password    = var.cloud_name == "" ? var.password : null
}
```

### 3. Render and apply
1. Supply template variables (locals, `tfvars`, or `-var` flags) for any values the template expects.
2. Run `terraform init`.
3. Execute `terraform plan` and `terraform apply`.

Tip: when reusing an existing network, keep `network_key`/`subnet_key` defined in your template variables—the YAML template uses those keys even if `render_network_manifest` is set to `false`.

## Module inputs
| Name | Type | Description | Default |
| --- | --- | --- | --- |
| `resource_templates` | `map(object({ template_path = string, vars = optional(map(any), {}) }))` | Template definitions rendered via `templatefile`. Each template must decode to the manifest schema below. | `{}` |
| `resource_manifests` | `list(map(any))` | Already-rendered manifest fragments. Helpful for environment overrides or resources that are easier to express inline. | `[]` |
| `name_prefix` | `string` | Optional prefix applied to resource names when the underlying OpenStack resource supports it. | `""` |

## Manifest schema
Each manifest is a YAML/JSON map. Sections are optional.

- `compute_instances` – map of instance keys to definitions. Provide either `image_id`/`image_name` and `flavor_id`/`flavor_name`. Optional fields include `name`, `key_pair`, `availability_zone`, `security_groups`, `networks` (list of maps with `uuid`, `name`, `port`, `fixed_ip_v4/v6`), `block_devices`, `attachments`, `floating_ip`, `scheduler_hints`, `metadata`, `user_data`, and `config_drive`.
- `networks` – map of network keys to Neutron network definitions. Supports the arguments from `openstack_networking_network_v2` such as `name`, `admin_state_up`, `mtu`, `external`, `shared`, `port_security_enabled`, `region`, `qos_policy_id`.
- `subnets` – map of subnet keys. Each entry needs `cidr` and either `network_id` or `network_ref` (the latter references a key from the `networks` map). Optional fields mirror `openstack_networking_subnet_v2`: `name`, `gateway_ip`, `ip_version`, `enable_dhcp`, `dns_nameservers`, `allocation_pools`, `description`, IPv6 settings.
- `security_groups` – map of security group keys. Top-level attributes mirror `openstack_networking_secgroup_v2`. Nest a `rules` map to inline rule definitions (`direction` is required; optionally `protocol`, `port_range_min/max`, `remote_ip_prefix`, `remote_group_id` or `remote_group_ref`, `description`, `region`).
- `volumes` – map of block storage volume keys with at least `size`. Optional attributes: `name`, `description`, `volume_type`, `availability_zone`, `image_id`, `snapshot_id`, `source_vol_id`, `metadata`.
- `floating_ip` blocks inside `compute_instances` – request allocation/association of floating IPs. Supply `floating_network_id` or `pool`; optional `delete_on_destroy`, `description`, `region`, `tenant_id`, or a pre-existing `port_id`.

The merged manifest is exposed via the `manifest` output for inspection or downstream tooling.

## Outputs
- `compute_instance_ids` – IDs of all compute instances created by the module.
- `network_ids` / `subnet_ids` – IDs of Neutron networks and subnets created by the module.
- `security_group_ids` – IDs of created security groups.
- `volume_ids` – IDs of Cinder volumes created by the module.
- `floating_ip_ids` / `floating_ip_addresses` – IDs and addresses for allocated floating IPs.
- `manifest` – merged manifest after template rendering (useful for debugging).

## Example configuration
The `examples/basic` folder shows an end-to-end stack with two compute instances, optional data volumes, floating IPs, and the ability to reuse an existing Neutron network. Key variables include:

- `image_name` / `image_id`, `flavor_name` – control the boot image and sizing.
- `public_key_path` or `key_pair` – register a new key pair or reference an existing one.
- `existing_network_id` / `existing_network_name`, `existing_subnet_id` – reuse existing networking instead of creating new resources.
- `assign_floating_ip`, `floating_network_id`, `floating_ip_pool`, `floating_ip_release_on_destroy` – manage floating IP lifecycle.
- `root_volume_size`, `data_volume_size`, `format_data_volume`, `data_volume_filesystem`, `data_volume_mount_path` – customise boot/data volume behaviour.

Refer to `examples/basic/variables.tf` for the full list of tunables and validations.

## Testing
The manifest engine can be tested locally without OpenStack access:

```bash
cd tests
GOCACHE=$(pwd)/.gocache go test ./...
```

Using a project-local Go build cache keeps the tests self-contained in sandboxed environments.

## Extending the module
To add new resource classes, update `modules/component_factory/internal_manifest` to aggregate the additional manifest data and declare the matching Terraform resources in `modules/component_factory/main.tf`. The manifest-centric design means new resources can be layered in without breaking existing templates.
