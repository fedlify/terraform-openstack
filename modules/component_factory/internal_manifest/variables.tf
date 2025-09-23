variable "resource_templates" {
  description = "Map of template definitions keyed by a class name. Each template renders a manifest describing resources to create."
  type = map(object({
    template_path = string
    vars          = optional(map(any), {})
  }))
  default = {}
}

variable "resource_manifests" {
  description = "List of manifest maps already rendered. Use this when you prefer to author the manifest directly instead of via a template."
  type        = list(map(any))
  default     = []
}

variable "name_prefix" {
  description = "Optional prefix applied to resource names when supported by the resource type."
  type        = string
  default     = ""
}
