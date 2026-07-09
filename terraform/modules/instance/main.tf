terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
    }
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node

  source_raw {
    file_name = "${var.vm_name}-user-data.yaml"
    data      = <<-EOF
    #cloud-config
    hostname: ${var.vm_name}
    timezone: America/Hermosillo
    users:
      - name: ${var.ci_user}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(var.ci_ssh_key)}
        sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_pwauth: false
    package_update: true
    packages:
      - qemu-guest-agent
    write_files:
      - path: /etc/ssh/sshd_config.d/99-hardening.conf
        content: |
          PermitRootLogin no
        permissions: '0644'
        owner: root:root
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - systemctl restart ssh
      - echo "cloud-init done" > /tmp/cloud-config.done
      EOF
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  node_name   = var.node
  vm_id       = var.vm_id
  name        = var.vm_name
  description = var.description
  tags        = var.tags
  started     = var.started
  on_boot     = var.on_boot

  stop_on_destroy = var.started

  agent {
    enabled = true
    trim    = true
  }

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores = var.vcpu
    type  = "host"
  }

  memory {
    dedicated = var.memory
    floating  = coalesce(var.memory_floating, var.memory)
  }

  efi_disk {
    datastore_id      = "local-zfs"
    type              = "4m"
    pre_enrolled_keys = true
  }

  disk {
    datastore_id = "local-zfs"
    discard      = "on"
    import_from  = var.image_file_id
    interface    = "scsi0"
    iothread     = true
    queues       = var.vcpu > 1 ? var.vcpu : 0
    size         = var.boot_disk_size
    ssd          = true
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = disk.value.datastore_id
      discard      = "on"
      interface    = disk.value.interface
      iothread     = true
      size         = disk.value.size
      ssd          = true
    }
  }

  initialization {
    datastore_id      = "local-zfs"
    interface         = "ide2"
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    dns {
      domain  = var.ci_dns_domain
      servers = var.ci_dns_server
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }

  dynamic "network_device" {
    for_each = var.network_devices
    content {
      mac_address = network_device.value.mac_address
      bridge      = network_device.value.bridge
      vlan_id     = network_device.value.vlan_id
      firewall    = network_device.value.firewall
    }
  }

  scsi_hardware = "virtio-scsi-single"

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order      = var.startup_order
      up_delay   = var.startup_up_delay
      down_delay = var.startup_down_delay
    }
  }
}
