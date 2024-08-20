variable "pvetoken" {
  ## set this var via environment variable TF_VAR_pvetoken
  description = "Proxmox API token for TF to use"
  type        = string
}

variable "TSIG_key" {
  ## set this var via environment variable TF_VAR_TSIG_key
  description = "TSIG key. Format: 'key_name.|key_secret')"
  type        = string
}
