# Component Factory Module

Component Factory composes multiple OpenStack building blocks from declarative manifests. Each manifest can be rendered from a template (`templatefile`) or passed directly, enabling you to keep reusable blueprints ("classes") for different stacks.

The module currently materialises:
- networks (`openstack_networking_network_v2`)
- subnets (`openstack_networking_subnet_v2`)
- security groups and rules (`openstack_networking_secgroup_v2` / `_rule_v2`)
- block storage volumes (`openstack_blockstorage_volume_v3`)
- compute instances (`openstack_compute_instance_v2`)

## Inputs
- `resource_templates` – map keyed by class name. Each entry exposes `template_path` and optional `vars`. The template must render YAML that matches the manifest schema below.
- `resource_manifests` – list of manifest maps that are already rendered. Use this to bypass templating.
- `name_prefix` – optional prefix applied to any resource that supports the `name` argument.

## Manifest structure
Every manifest is a YAML (or JSON) object. Sections are optional; if a section is missing no resources of that type are created.

```yaml
compute_instances:     # map of instance_key -> definition
networks:              # map of network_key -> definition
subnets:               # map of subnet_key -> definition
security_groups:       # map of security_group_key -> definition
volumes:               # map of volume_key -> definition
```

### `compute_instances`
Required:
- `flavor_id` or `flavor_name`
- `image_id` or `image_name`

Optional highlights: `name`, `key_pair`, `availability_zone`, `security_groups`, `user_data`, `config_drive`, `metadata`, `scheduler_hints`, `networks` (list of network blocks), `block_devices` (list), `personalities` (list with `file`/`content`), and `attachments` (list). `block_devices` lets you boot from volumes (for example, a Cinder volume created from an image). `attachments` associates existing or module-managed volumes after the server is created (`volume_key` or `volume_id`, optional `device`). When targeting pre-existing networks, supply `networks` entries with `uuid` so instances attach without creating new Neutron networks. To allocate and associate a floating IP, add a `floating_ip` object with `floating_network_id` or `pool` (and optional `floating_ip`, `description`, `region`, `delete_on_destroy`, etc.).

### `networks`
Optional fields mirror `openstack_networking_network_v2`: `name`, `admin_state_up`, `description`, `mtu`, `region`, `external`, `shared`, `tenant_id`, `port_security_enabled`, `qos_policy_id`. Omit the entire section when reusing an existing network. Floating IP association relies on Neutron to expose an external network, so be sure to provide one of the supported identifiers.

### `subnets`
Required: `cidr` and either `network_id` or `network_ref` (the latter references a network key rendered by this module). Optional: `name`, `ip_version`, `gateway_ip`, `enable_dhcp`, `dns_nameservers`, `allocation_pools`, `host_routes`, IPv6 settings, `description`.

### `security_groups`
Top-level fields mirror `openstack_networking_secgroup_v2`. Add nested `rules` map for inline rule creation. Each rule must provide `direction` and can include `ethertype`, `protocol`, `port_range_min`, `port_range_max`, `remote_ip_prefix`, `remote_group_id`, `remote_group_ref`, `description`, `region`. Rules inherit the security group they are nested under unless `security_group_id` is set explicitly.

### `volumes`
Required: `size`. Optional: `name`, `description`, `volume_type`, `availability_zone`, `image_id`, `snapshot_id`, `metadata`, `source_vol_id`.

## Outputs
- `compute_instance_ids`
- `network_ids`
- `subnet_ids`
- `security_group_ids`
- `volume_ids`
- `floating_ip_ids`
- `manifest` – merged manifest after template rendering.

## Adding new resource types
Extend the module by introducing new locals that aggregate your resource definitions and declaring matching Terraform resources with `for_each`. The manifest structure is intentionally map based so that new resource classes can be slotted in with minimal refactoring.

### Implementation notes

Manifest aggregation is implemented in the sibling module `internal_manifest` so that it can be tested independently of any OpenStack provider plugins. The top-level module consumes that output to drive resource creation while the Go-based tests exercise the shared manifest engine.
