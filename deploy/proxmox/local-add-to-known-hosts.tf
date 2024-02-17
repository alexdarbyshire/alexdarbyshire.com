locals {
  ssh_hosts = proxmox_virtual_environment_vm.ubuntu_vm[*].ipv4_addresses[1][0]
}

#Add machines to known hosts after creating
resource "null_resource" "known_hosts" {

  provisioner "local-exec" {
    command = <<EOT
    sleep 20;
    %{for host_ip in local.ssh_hosts}
	ssh-keygen -R ${host_ip} 
	ssh-keyscan -H ${host_ip} >> ~/.ssh/known_hosts
    %{ endfor ~} 
    EOT
       interpreter = ["/bin/bash", "-c"]
    }
}
