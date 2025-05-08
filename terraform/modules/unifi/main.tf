terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.41.0"
    }
  }
}

provider "unifi" {
  username       = local.UNIFI_USERNAME
  password       = local.UNIFI_PASSWORD
  api_url        = local.UNIFI_CONTROLLER_URL
  site           = local.UNIFI_SITE
  allow_insecure = true
}

# Main Network
resource "unifi_network" "main" {
  name         = var.NETWORK.name
  purpose      = "corporate"
  subnet       = var.NETWORK.subnet
  dhcp_enabled = var.NETWORK.dhcp_enabled
  dhcp_start   = var.NETWORK.dhcp_start
  dhcp_stop    = var.NETWORK.dhcp_stop
  dhcp_dns     = var.NETWORK.dns_servers
  vlan_id      = 1
}

# WAN Networks
resource "unifi_network" "wan" {
  for_each = { for idx, network in var.WAN_NETWORKS : idx => network }

  name     = each.value.name
  purpose  = "wan"
  wan_type = each.value.wan_type
  wan_dns = [
    each.value.wan_dns1,
    each.value.wan_dns2,
    each.value.wan_dns3,
    each.value.wan_dns4
  ]
}

# Port Forwards
resource "unifi_port_forward" "rules" {
  for_each = {
    for rule in var.PORT_FORWARDS : rule.name => rule
    if rule.enabled
  }

  name     = each.value.name
  protocol = each.value.protocol
  dst_port = each.value.dst_port
  fwd_ip   = each.value.dst_ip
  fwd_port = each.value.dst_port
} 