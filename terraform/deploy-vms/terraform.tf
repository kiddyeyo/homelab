terraform {
  required_version = "~> 1.15.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.endpoint
  api_token = var.api_token
  insecure  = var.insecure

  ssh {
    agent       = true
    username    = var.ssh_username
    private_key = file("~/.ssh/id_ed25519")
  }
}
