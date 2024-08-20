terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.61.1"
    }

    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.1"
    }

  }
}

provider "proxmox" {
  endpoint  = "https://pve.lan:8006/"
  api_token = var.pvetoken
  ssh {
    agent    = true
    username = "iac"
  }
}

provider "dns" {
  update {
    server        = "ns1.lan"
    key_name      = element(split("|", var.TSIG_key), 0)
    key_secret    = element(split("|", var.TSIG_key), 1)
    key_algorithm = "hmac-sha256"
  }
}

