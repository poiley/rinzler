terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.41.0"
    }
  }
}

provider "unifi" {
  username       = var.unifi_username
  password       = var.unifi_password
  api_url        = var.unifi_controller_url
  site           = var.unifi_site
  allow_insecure = true
}

# Main Network
resource "unifi_network" "main" {
  name         = var.network.name
  purpose      = "corporate"
  subnet       = var.network.subnet
  dhcp_enabled = var.network.dhcp_enabled
  dhcp_start   = var.network.dhcp_start
  dhcp_stop    = var.network.dhcp_stop
  dhcp_dns     = var.network.dns_servers
  vlan_id      = 1
}

# WAN Networks
resource "unifi_network" "wan" {
  for_each = { for idx, network in var.wan_networks : idx => network }

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
    for rule in var.port_forwards : rule.name => rule
    if rule.enabled
  }

  name     = each.value.name
  protocol = each.value.protocol
  dst_port = each.value.dst_port
  fwd_ip   = each.value.dst_ip
  fwd_port = each.value.dst_port
} 