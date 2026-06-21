module "ubuntu_cloud_minimal_template" {
  source = "../modules/template"

  node = "pve2"

  # Image Variables
  image_filename = "resolute-server-cloudimg-amd64v3.qcow2"
  image_url      = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img"
  image_checksum = "345112dce3a0728c664bdf9f1a0ecd7bb576e91558dc93f1f827e7e228288d26"

  # VM Template Variables
  vm_id       = 8001
  vm_name     = "prueba"
  description = "Terraform generated template on ${timestamp()}"
  tags        = ["terraform", "template", "ubuntu"]
}
