# Create Single VM
module "pve1_postgresql_database" {
  source = "../modules/instance"

  node         = "pve1"
  vm_id        = 200
  vm_name      = "postgresql"
  template_id  = 9000
  ci_user      = "db-user"
  ci_ssh_key   = "~/.ssh/id_ed25519.pub"
  ci_ipv4_cidr = "192.168.100.10/24"

  disks = [
    {
      disk_interface = "scsi0",
      disk_size      = 32,
    },
  ]
}

output "id" {
  value = module.pve1_postgresql_database.id
}
