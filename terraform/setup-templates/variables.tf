variable "endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = false
}

variable "ssh_username" {
  description = "SSH username for Proxmox host"
  type        = string
  default     = "terraform"
} 

