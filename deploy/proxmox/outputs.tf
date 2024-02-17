#The IP addresses of the VMs
output "vm_k8s_ipv4_address" {
  value = proxmox_virtual_environment_vm.ubuntu_vm[*].ipv4_addresses[1][0]
}


