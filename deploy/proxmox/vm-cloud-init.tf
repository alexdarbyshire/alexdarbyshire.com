#Custom cloud-init to add qemu-guest-agent and SSH key

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = var.virtual_environment.storage_nas 
  node_name    = "agri"

  source_raw {
    data = <<EOF
#cloud-config
users:
  - default
  - name: ubuntu
    groups:
      - sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ${trimspace(data.local_file.ssh_public_key.content)}
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
    - apt update
    - apt install -y qemu-guest-agent net-tools
    - timedatectl set-timezone Australia/Brisbane 
    - systemctl enable qemu-guest-agent
    - systemctl start qemu-guest-agent
    - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "cloud-config.yaml"
  }
}


