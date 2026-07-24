terraform {
  required_version = "~> 1.15.0"
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1"

    use_path_style = true
    use_lockfile   = true

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    endpoints = {
      s3 = "https://s3.infra.sintaq.net"
    }
  }
}

provider "sops" {}

provider "proxmox" {
  endpoint  = "https://pve.infra.sintaq.net:8006"
  api_token = data.sops_file.secrets.data["PROXMOX_API_TOKEN"]
  insecure  = true

  ssh {
    agent       = false
    username    = "erickcastillo"
    private_key = file("~/.ssh/cicd")
  }
}
