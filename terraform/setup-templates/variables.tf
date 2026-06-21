variable "endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}
