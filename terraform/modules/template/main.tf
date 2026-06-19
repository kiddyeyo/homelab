terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
  }
}

resource "proxmox_virtual_environment_download_file" "image" {
  node_name          = var.node
  content_type       = var.image_content_type
  datastore_id       = var.image_datastore_id
  file_name          = var.image_filename
  url                = var.image_url
  checksum           = var.image_checksum
  checksum_algorithm = var.image_checksum_algorithm
  overwrite          = var.image_overwrite
  upload_timeout     = var.image_upload_timeout

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_vm" "vm_template" {
  depends_on = [proxmox_virtual_environment_download_file.image]

  node_name   = var.node
  vm_id       = var.vm_id
  name        = var.vm_name
  description = var.description
  tags        = var.tags
  bios        = var.bios
  machine     = var.machine_type
  started     = false
  template    = true

  agent {
    enabled = var.qemu_guest_agent
  }

  # cloud-init config
  initialization {
    datastore_id         = var.ci_datastore_id
    interface            = var.ci_interface
    type                 = var.ci_datasource_type
    meta_data_file_id    = var.ci_meta_data
    network_data_file_id = var.ci_network_data
    user_data_file_id    = var.ci_user_data
    vendor_data_file_id  = var.ci_vendor_data
  }

  cpu {
    cores = var.vcpu
    type  = var.vcpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_floating
  }

  dynamic "efi_disk" {
    for_each = (var.bios == "ovmf" ? [1] : [])
    content {
      datastore_id      = var.efi_disk_storage
      file_format       = var.efi_disk_format
      type              = var.efi_disk_type
      pre_enrolled_keys = var.efi_disk_pre_enrolled_keys
    }
  }

  disk {
    file_id      = proxmox_virtual_environment_download_file.image.id
    datastore_id = var.disk_storage
    interface    = var.disk_interface
    size         = var.disk_size
    file_format  = var.disk_format
    cache        = var.disk_cache
    iothread     = var.disk_iothread
    ssd          = var.disk_ssd
    discard      = var.disk_discard
  }
}

output "id" {
  value = proxmox_virtual_environment_vm.vm_template.id
}
