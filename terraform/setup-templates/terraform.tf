terraform {
  required_version = "~> 1.15.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.109.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

provider "sops" {}

provider "proxmox" {
  endpoint  = data.sops_file.secrets.data["PROXMOX_ENDPOINT"]
  api_token = data.sops_file.secrets.data["PROXMOX_API_TOKEN"]
  insecure  = true
}
