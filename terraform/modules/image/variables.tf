variable "node" {
  description = "Proxmox node where the VM will be created, e.g. `pve2`."
  type        = string
}

variable "image_filename" {
  description = "Target filename for the downloaded image. Use a *.qcow2 name to hint the import format."
  type        = string
}

variable "image_url" {
  description = "Cloud image URL."
  type        = string
}

variable "image_checksum" {
  description = "Image checksum value."
  type        = string
}

variable "image_checksum_algorithm" {
  description = "Image checksum algorithm."
  type        = string
  default     = "sha256"
}

variable "image_datastore_id" {
  description = "PVE datastore for image downloads."
  type        = string
  default     = "local"
}
