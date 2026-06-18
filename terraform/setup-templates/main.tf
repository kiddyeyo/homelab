module "ubuntu_cloud_minimal_template" {
  source = "../modules/template"

  node = "pve1"

  # Image Variables
  image_filename = "noble-minimal-cloudimg-amd64.img"
  image_url      = "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"
  image_checksum = "c37d5ee2015a1039d58520b11e6fc012e695d6a224d0250c7a2eff8e91447adc"

  # VM Template Variables
  vm_id       = 9000
  vm_name     = "ubuntu-2404-cloud-minimal"
  description = "Terraform generated template on ${timestamp()}"
  tags        = ["terraform", "template", "ubuntu"]
}
