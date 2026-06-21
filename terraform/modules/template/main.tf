terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
  }
}

resource "proxmox_download_file" "image" {

  node_name          = var.node
  content_type       = "import"
  datastore_id       = var.image_datastore_id
  file_name          = var.image_filename
  url                = var.image_url
  checksum           = var.image_checksum
  checksum_algorithm = var.image_checksum_algorithm

}

resource "proxmox_virtual_environment_vm" "vm_template" {
  depends_on = [proxmox_download_file.image]

  agent {
    enabled = var.agent_enabled
    trim    = true
  }

  bios = "ovmf"

  cpu {
    cores = var.vcpu
    type  = "host"
  }

  description = var.description

  disk {
    datastore_id = "local-zfs"
    discard      = "on"
    import_from  = proxmox_download_file.image.id
    interface    = "scsi0"
    iothread     = true
    queues       = var.vcpu > 1 ? var.vcpu : 0
    size         = var.disk_size
    ssd          = true
  }

  efi_disk {
    datastore_id      = "local-zfs"
    type              = "4m"
    pre_enrolled_keys = true
  }

  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
  }

  machine = "q35"

  memory {
    dedicated = var.memory
    floating  = var.memory_floating
  }

  node_name = var.node
  name      = var.vm_name

  serial_device {
    device = "socket"
  }

  scsi_hardware = "virtio-scsi-single"
  started       = false
  tags          = var.tags
  template      = true

  vga {
    type = "serial0"
  }

  vm_id = var.vm_id
}

output "id" {
  value = proxmox_virtual_environment_vm.vm_template.id
}
