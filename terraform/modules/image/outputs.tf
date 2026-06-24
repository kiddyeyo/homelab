output "id" {
  description = "File ID of the downloaded image, for use as a VM disk import_from source."
  value       = proxmox_download_file.image.id
}
