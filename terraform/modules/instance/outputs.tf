output "id" {
  description = "Proxmox VM ID of the created instance."
  value       = proxmox_virtual_environment_vm.vm.id
}

output "ci_user" {
  description = "Bootstrap cloud-init user provisioned on the VM."
  value       = var.ci_user
}

output "ipv4_address" {
  description = "First IPv4 reported by the QEMU guest agent. Null until the agent reports (VM running + qemu-guest-agent up). Index [1] skips the loopback at [0]."
  value       = try(proxmox_virtual_environment_vm.vm.ipv4_addresses[1][0], null)
}
