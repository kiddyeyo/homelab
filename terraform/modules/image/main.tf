terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
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
