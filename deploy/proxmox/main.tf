terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.46.4"
    }
  }
}

provider "proxmox" {
  endpoint = var.virtual_environment.endpoint
  insecure = true 				# Using self-signed TLS certificate currently
  username = var.virtual_environment.username
  password = var.virtual_environment.password

  ssh {
    agent = true
    }

}

