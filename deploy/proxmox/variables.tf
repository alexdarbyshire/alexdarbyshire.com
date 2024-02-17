variable virtual_environment {
  type = object({
    endpoint = string		#Proxmox hostname and port https://proxmonx-instance:8006
    node_name = string		#Proxmox node to create VMs on
    storage_nas = string	#Proxmox storage ID to store cloud images on
    storage_ssd = string	#Proxmox storage ID for the LVM
    username = string		#Proxmox username e.g. root@pam
    password = string	        #Proxmox password	
    vm_count = number		#Number of VMs to spin up
  })
}
