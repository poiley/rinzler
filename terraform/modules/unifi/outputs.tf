output "NETWORKS" {
  description = "Created UniFi networks"
  value = {
    main = unifi_network.main
    wan  = unifi_network.wan
  }
}

output "PORT_FORWARDS" {
  description = "Created UniFi port forwards"
  value       = unifi_port_forward.rules
}

output "UNIFI_CONTROLLER_URL" {
  description = "URL of the UniFi controller"
  value       = local.UNIFI_CONTROLLER_URL
}

output "UNIFI_SITE" {
  description = "Name of the UniFi site"
  value       = local.UNIFI_SITE
}

output "MAIN_NETWORK" {
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