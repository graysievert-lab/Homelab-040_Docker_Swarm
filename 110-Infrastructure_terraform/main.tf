
locals {
  hostname    = "swarm"
  vm_id       = 2001
  description = "Docker Swarm single node"
  tags        = ["swarm", "linux", "cloudinit", "infra"]

  proxmox_node   = "pve" #name of proxmox node"
  ssh_ca_record = "cert-authority ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDTS/AYbRXLDv1EYUBPouFROZ5fTGMge5jMZA7prfMKHMhvCSUQFnS665BQH5pMwxjjXtinn3n1uCR41SWumq6YVWHZZdVm3o2jCfJlKwkax4ZHFeGl3eSXqEqrTauWWUqP35rKbZGsAqAzucBHAmSoQbeN8P7YPVNweD6EUkrFgAB/1HdMPnHlhSH6GSFOKj690kUzkWP+tRqnyt4aQE6nMSsP1plAFDJZOrjVAeyLPKTQFJ1SDbaKD1ZoAJ1ml+BJXFNwPNVOwXQZcfHb6t8gxtxcDWqtNQj/5jicYp8TsnLuHuXQmGjxq3DOi9nDdsVIRX6Cdpjwf+CWbT4VTBZ+ESF5AHFwpe0m67hE2XvAqWb+Bzn8re1ezv/K+0K40vvvrauCvETxjnQOuFwNIhgrulbwFqVEjbRvIgzcY6+nrs4N7A10BAUHnFm5sHZnFVw1QU2HqYUFLosALEhulA1NZr8Zakww9ik7XnWiFyF909CsHHhcdvo+NxmpErethiItVbfflKKft3lN40uUCCOqUUyVvJpzX/LTn8Gbnu99CxxDewKF14DyUpqoSGsiGoXBg5+w6nHZbDzN3JDdYDtLZ73lQqc7bE85bPD45hn7Oeu+rCJvzsXf1/kU8GlwS6tx6ghJloJvShS45E34Zr5eEEYNgoxI/mg0+9Ks9YNTQw=="

  address      = "10.1.2.2"
  netmask      = "/24"
  gateway      = "10.1.2.100"

  zone_forward = "lan."
  zone_reverse = "2.1.10.in-addr.arpa."
}



########################################
## pool
########################################
resource "proxmox_virtual_environment_pool" "main" {
  comment = "Pool for Docker Swarm"
  pool_id = "swarm"
}

########################################
## Virtual Machine
########################################
module "proxmox_vm_main" {
  source = "git::https://github.com/graysievert-lab/terraform-modules-proxmox_vm?ref=v1.0.0"

  metadata = {
    node_name    = local.proxmox_node
    datastore_id = "local-zfs"
    image        = "local:iso/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2.img"
    agent        = true
    description  = local.description
    name         = "${local.hostname}"
    pool_id      = proxmox_virtual_environment_pool.main.id
    tags         = local.tags
    vm_id        = local.vm_id
  }

  hardware = {
    mem_dedicated_mb = 4096
    mem_floating_mb  = 1024
    cpu_sockets      = 1
    cpu_cores        = 2
    disk_size_gb     = 40
  }

  cloudinit = {
    meta_config_file   = proxmox_virtual_environment_file.cloudinit_meta_config.id
    user_config_file   = proxmox_virtual_environment_file.cloudinit_user_config.id
    vendor_config_file = proxmox_virtual_environment_file.cloudinit_vendor_config.id
    ipv4 = {
      address = "${local.address}${local.netmask}"
      gateway = local.gateway
    }
  }
}
