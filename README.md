# terraform-openstack

Reusable Terraform tooling for building OpenStack component stacks from shareable manifests. The `component_factory` module turns class-style templates (rendered with `templatefile`) into concrete OpenStack networks, subnets, security groups, volumes, and compute instances.

## Repository layout
- `modules/component_factory` – reusable module with manifest-driven resource creation.
- `examples/basic` – end-to-end example showing how to feed the module with a template and an inline manifest.
- `tests` – Terraform fixture plus Go-based assertions that exercise the manifest engine without touching OpenStack.

## Quick start
1. Copy `examples/basic` somewhere inside your Terraform project or reference the module directly via `source = "github.com/<org>/terraform-openstack//modules/component_factory"`.
2. Provide OpenStack credentials (see `examples/basic/variables.tf`).
3. Render one or more manifests either from templates (`resource_templates`) or by supplying raw maps (`resource_manifests`). Ensure resource keys stay unique across manifests. The bundled template can reuse existing Neutron network/subnet pairs via `existing_network_id`/`existing_subnet_id` and attach additional security groups via `additional_security_groups`.
4. Optionally set `public_key_path` to upload a local SSH public key before the compute instance is created, or leave it blank to reference an already-registered key pair. You can also toggle `assign_floating_ip` with a network ID/pool to have the module allocate and attach a floating IP automatically, and tune `root_volume_size`/`data_volume_size`. Set `format_data_volume = true` (with filesystem and mount path) to have cloud-init format and mount the attached data disk on first boot.
5. Run `terraform init` and `terraform apply` from within your configuration to materialise the defined components.

See `modules/component_factory/README.md` for the manifest schema and extensibility notes.

## Example variables (highlights)

- `existing_network_id` / `existing_network_name` – reuse an existing Neutron network instead of creating one. Provide either the UUID or the name.
- `existing_subnet_id` – optional subnet UUID when reusing an existing network.
- `root_volume_size` / `root_volume_delete_on_termination` – control the boot volume created from the image for each instance.
- `data_volume_size`, `data_volume_device`, `format_data_volume`, `data_volume_filesystem`, `data_volume_mount_path` – manage secondary data disks and optionally format/mount them through cloud-init.
- `assign_floating_ip`, `floating_network_id`/`floating_ip_pool`, `floating_ip_release_on_destroy` – automatically allocate, attach, and optionally retain floating IPs.
- `additional_security_groups` – supply extra security groups for the compute instances beyond the module-managed ones.

## Testing

The test harness focuses on the manifest engine so it can run without an OpenStack endpoint or provider plugins. To execute the checks:

```
cd tests
GOCACHE=$(pwd)/.gocache go test ./...
```

Setting `GOCACHE` keeps the Go build cache inside the repository, which helps in sandboxed environments where the default cache path is read-only.
