data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.yml"
  input_type  = "yaml"
}

module "ubuntu_2604_cloud_image" {
  source = "../modules/image"

  node                     = "pve"
  image_filename           = "resolute-server-cloudimg-amd64v3.qcow2"
  image_url                = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img"
  image_checksum           = "3135ef17fd9de0046d911cbe6188988909eac1c2d406bbb62eb162f9f9e9a190"
  image_checksum_algorithm = "sha256"
}

module "technitium-dns1" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 201
  vm_name     = "technitium-dns1"
  description = "VM de DNS Server 1: Technitium"
  tags        = ["terraform", "technitium"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "technitium-dns1"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:02" # TODO: reemplazar por la MAC real reservada en el DHCP
  }]

  vcpu   = 2
  memory = 2048

  boot_disk_size = 32
}

module "traefik" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 202
  vm_name     = "traefik"
  description = "VM de reverse proxy centralizado: Traefik"
  tags        = ["terraform", "traefik"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "traefik"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:03" # TODO: reemplazar por la MAC real reservada en el DHCP
  }]

  vcpu   = 2
  memory = 2048

  boot_disk_size = 32
}

output "ubuntu_2604_cloud_image_id" {
  description = "File ID of the downloaded image, for use as a VM disk import_from source."
  value       = module.ubuntu_2604_cloud_image.id
}
