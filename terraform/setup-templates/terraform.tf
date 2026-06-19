terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.endpoint  # Como dice la documentación
  api_token = var.api_token # Como dice la documentación
  insecure  = var.insecure  # Como dice la documentación

  ssh {
    agent       = true
    username    = var.ssh_username
    private_key = file("~/.ssh/id_ed25519")
  }
}
