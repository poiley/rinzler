output "networks" {
  description = "Created UniFi networks"
  value = {
    main = unifi_network.main
    wan  = unifi_network.wan
  }
}

output "port_forwards" {
  description = "Created UniFi port forwards"
  value       = unifi_port_forward.rules
}

output "unifi_controller_url" {
  description = "URL of the UniFi controller"
  value       = var.unifi_controller_url
}

output "unifi_site" {
  description = "Site name in UniFi controller"
  value       = var.unifi_site
}

output "main_network" {
  description = "Main network configuration"
  value = {
    name         = unifi_network.main.name
    subnet       = unifi_network.main.subnet
    dhcp_enabled = unifi_network.main.dhcp_enabled
    dhcp_start   = unifi_network.main.dhcp_start
    dhcp_stop    = unifi_network.main.dhcp_stop
    dhcp_dns     = unifi_network.main.dhcp_dns
  }
} 