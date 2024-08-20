########################################
## DNS
########################################

resource "dns_a_record_set" "main" {
  zone = local.zone_forward
  name = local.hostname
  addresses = [
    "${local.address}"
  ]
  ttl = 900
}
resource "dns_ptr_record" "main" {
  zone = local.zone_reverse
  name = element(split(".", local.address), 3)
  ptr  = "${local.hostname}.${local.zone_forward}"
  ttl  = 900
}


resource "dns_cname_record" "wildcard" {
  depends_on = [ dns_a_record_set.main ]
  zone  = local.zone_forward
  name  = "*.${local.hostname}"
  cname = "${local.hostname}.${local.zone_forward}"
  ttl   = 900
}
