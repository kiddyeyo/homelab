data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.yml"
  input_type  = "yaml"
}

module "ubuntu_2604_cloud_image" {
  source = "../modules/image"

  node                     = "pve"
  image_filename           = "resolute-server-cloudimg-amd64v3.qcow2"
  image_url                = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img"
  image_checksum           = "c85446d1255b25b146649b76d3d2237d33d47fa903004abd813a03b360850d5c"
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
    mac_address = "BC:24:11:00:00:02"
  }]

  vcpu            = 2
  memory          = 4096
  memory_floating = 2048

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
    mac_address = "BC:24:11:00:00:03"
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 32
}

module "monitoring" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 203
  vm_name     = "monitoring"
  description = "VM de monitoring: Dozzle"
  tags        = ["terraform", "monitoring"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "monitoring "
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:04"
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 32
}

module "homepage" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 204
  vm_name     = "homepage"
  description = "VM de la página de inicio: Homepage"
  tags        = ["terraform", "homepage"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "homepage"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:05"
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 32
}

module "vaultwarden" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 205
  vm_name     = "vaultwarden"
  description = "VM de password manager: Vaultwarden"
  tags        = ["terraform", "vaultwarden"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "vaultwarden"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:06"
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 32
}

module "filebrowser" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 206
  vm_name     = "filebrowser"
  description = "VM para el sistema de gestión de archivos: FileBrowser"
  tags        = ["terraform", "filebrowser"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "filebrowser"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:07"
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 32
}

module "immich" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 207
  vm_name     = "immich"
  description = "VM para el sistema de gestion de imagenes: Immich"
  tags        = ["terraform", "immich"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "immich"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:08"
  }]

  vcpu            = 6
  memory          = 6144
  memory_floating = 3072

  boot_disk_size = 96
}

module "twingate" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 208
  vm_name     = "twingate"
  description = "VM del conector uno del VPN: Twingate"
  tags        = ["terraform", "twingate"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "twingate"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:09"
    queues      = 2
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 16
}

module "twingate2" {
  source = "../modules/instance"

  node        = "pve"
  vm_id       = 209
  vm_name     = "twingate2"
  description = "VM del conector dos del VPN: Twingate"
  tags        = ["terraform", "twingate2"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user    = "twingate2"
  ci_ssh_key = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]

  network_devices = [{
    mac_address = "BC:24:11:00:00:10"
    queues      = 2
  }]

  vcpu            = 2
  memory          = 2048
  memory_floating = 1024

  boot_disk_size = 16
}

output "ubuntu_2604_cloud_image_id" {
  description = "File ID of the downloaded image, for use as a VM disk import_from source."
  value       = module.ubuntu_2604_cloud_image.id
}
