########################################
## Cloud-init custom configs
########################################


resource "proxmox_virtual_environment_file" "cloudinit_meta_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.proxmox_node
  source_raw {
    file_name = "${local.hostname}-meta-config.yaml"
    data      = <<EOF
#cloud-config
local-hostname: ${local.hostname}.${local.zone_forward}
instance-id: ${md5(local.hostname)}
EOF
  }
}

resource "proxmox_virtual_environment_file" "cloudinit_user_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.proxmox_node
  source_raw {
    file_name = "${local.hostname}-user-config.yaml"
    data      = <<EOF
#cloud-config
ssh_authorized_keys:
  - "${local.ssh_ca_record}"
user:
  name: rocky
users:
  - default
EOF
  }
}

resource "proxmox_virtual_environment_file" "cloudinit_vendor_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.proxmox_node
  source_raw {
    file_name = "${local.hostname}-vendor-config.yaml"
    data      = <<EOF
#cloud-config
packages:
    - qemu-guest-agent

runcmd:
  - echo -e "I am $(whoami) at $(hostname -f), myenv is\n$(declare -p)"
  - curl -k -o /etc/pki/ca-trust/source/anchors/localCA.crt https://acme.lan:8443/roots.pem && update-ca-trust extract
EOF
  }
}


