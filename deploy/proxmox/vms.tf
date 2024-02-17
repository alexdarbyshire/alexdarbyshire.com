resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  count = var.virtual_environment.vm_count

  name      = "k8s-${count.index}-ubuntu"
  node_name = var.virtual_environment.node_name

  vm_id = "${format("8%02s", count.index)}"

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = var.virtual_environment.storage_ssd
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  network_device {
    bridge = "vmbr0"
  }

}


#Specify the image to use
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.virtual_environment.storage_nas 
  node_name    = var.virtual_environment.node_name

  url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
