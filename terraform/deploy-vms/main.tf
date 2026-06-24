data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.yml"
  input_type  = "yaml"
}

module "ubuntu_2604_cloud_image" {
  source = "../modules/image"

  node                     = "pve2"
  image_filename           = "resolute-server-cloudimg-amd64v3.qcow2"
  image_url                = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img"
  image_checksum           = "4d39478a817bb42e83b06834ce3f763178ec015213732a1031634b96f6d6bf00"
  image_checksum_algorithm = "sha256"
}

module "prueba_vm" {
  source = "../modules/instance"

  node        = "pve2"
  vm_id       = 202
  vm_name     = "prueba-vm"
  description = "VM de prueba: discos múltiples + floating memory"
  tags        = ["terraform", "prueba"]

  image_file_id = module.ubuntu_2604_cloud_image.id

  ci_user       = "bootstrap"
  ci_ssh_key    = data.sops_file.secrets.data["PROXMOX_SSH_PUBLIC_KEY"]
  ci_dns_server = ["192.168.100.23"]

  vcpu   = 2
  memory = 1024


  boot_disk_size = 40
}

output "prueba_id" {
  value = module.prueba_vm.id
}

output "prueba_ci_user" {
  value = module.prueba_vm.ci_user
}

output "prueba_ipv4" {
  value = module.prueba_vm.ipv4_address
}
