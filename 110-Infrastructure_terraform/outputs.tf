# Output variable definitions

output "vm_id" {
  description = "VM ID"
  value       = module.proxmox_vm_main.vm_id
}

output "ipv4_addresses" {
  description = "IP v4 addresses"
  value       = module.proxmox_vm_main.ipv4_addresses
}

output "ipv6_addresses" {
  description = "IP v6 addresses"
  value       = module.proxmox_vm_main.ipv6_addresses
}

output "mac_addresses" {
  description = "MAC addresses"
  value       = module.proxmox_vm_main.mac_addresses
}
