## Image Variables
variable "node" {
  description = "Name of Proxmox node to provision VM on, e.g. `pve`."
  type        = string
}

variable "image_filename" {
  description = "Filename, default `null` will extract name from URL."
  type        = string
}

variable "image_url" {
  description = "Image URL."
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
  description = "PVE disk location for images."
  type        = string
  default     = "local"
}

## VM Variables
variable "vm_id" {
  description = "ID number for new VM."
  type        = number
}

variable "vm_name" {
  description = "Name, must be alphanumeric (may contain dash: `-`). Defaults to PVE naming, `VM <VM_ID>`."
  type        = string
}

variable "description" {
  description = "VM description."
  type        = string
}

variable "tags" {
  description = "Proxmox tags for the VM."
  type        = list(string)
  default     = null
}

variable "agent_enabled" {
  description = "Enable QEMU guest agent."
  type        = bool
  default     = true
}

variable "vcpu" {
  description = "Number of CPU cores."
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory size in `MiB`."
  type        = number
  default     = 1024
}

variable "memory_floating" {
  description = "Minimum memory size in `MiB`, setting this value enables memory ballooning."
  type        = number
  default     = 1024
}

## Disk Variables
variable "disk_size" {
  description = "Disk size in `GiB`."
  type        = number
  default     = 32
}
