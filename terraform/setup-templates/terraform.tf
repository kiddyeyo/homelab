terraform {
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
  insecure  = true
}
