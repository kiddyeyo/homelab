variable "node" {
  description = "Proxmox node where the VM will be created, e.g. `pve2`."
  type        = string
}

variable "vm_id" {
  description = "ID for the new VM."
  type        = number
}

variable "vm_name" {
  description = "VM hostname (alphanumeric and dashes only)."
  type        = string
}

variable "description" {
  description = "VM description shown in Proxmox UI."
  type        = string
}

variable "tags" {
  description = "Proxmox tags for the VM."
  type        = list(string)
}

variable "image_file_id" {
  description = "File ID of the image to import as the boot disk (e.g. module.<image>.id)."
  type        = string
}

variable "vcpu" {
  description = "Number of CPU cores."
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MiB."
  type        = number
  default     = 2048
}

variable "memory_floating" {
  description = "Minimum RAM in MiB for ballooning. Null sets floating equal to `memory`."
  type        = number
  default     = null
}

variable "started" {
  description = "Start the VM after provisioning."
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start VM automatically when Proxmox host boots."
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Boot order priority (lower = earlier). Null disables managed startup."
  type        = number
  default     = null
}

variable "startup_up_delay" {
  description = "Seconds to wait after VM starts before booting the next VM."
  type        = number
  default     = null
}

variable "startup_down_delay" {
  description = "Seconds to wait before shutting down the next VM."
  type        = number
  default     = null
}

variable "boot_disk_size" {
  description = "Size in GiB of the boot disk imported from the image."
  type        = number
  default     = 32
}

variable "disks" {
  description = "Additional data disks (beyond the boot disk)."
  type = list(object({
    datastore_id = optional(string, "local-zfs")
    interface    = optional(string, "scsi1")
    size         = optional(number, 32)
  }))
  default = []
}

variable "network_devices" {
  description = "NIC list. mac_address is required so the address must be reserved in DHCP before the VM is created."
  type = list(object({
    mac_address = string
    bridge      = optional(string, "vmbr0")
    vlan_id     = optional(number, null)
    firewall    = optional(bool, true)
  }))
}

variable "ci_user" {
  description = "Bootstrap cloud-init user provisioned in the generated user-data snippet."
  type        = string
}

variable "ci_ssh_key" {
  description = "Public SSH key content for the bootstrap user (e.g. the output of `cat ~/.ssh/id_ed25519.pub`)."
  type        = string
  sensitive   = true
}

variable "ci_dns_server" {
  description = "DNS resolver IP. Null (default) lets the guest inherit the Proxmox host's DNS settings."
  type        = list(string)
  default     = null
}

variable "ci_package_upgrade" {
  description = "Run full package upgrade during cloud-init. Slow at VM creation time; prefer false and let Ansible handle upgrades."
  type        = bool
  default     = false
}

variable "ci_dns_domain" {
  description = "DNS search domain. Null (default) lets the guest inherit the Proxmox host's DNS settings."
  type        = string
  default     = null
}
