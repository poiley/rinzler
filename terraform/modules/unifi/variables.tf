variable "unifi_api_key" {
  description = "UniFi API key"
  type        = string
  sensitive   = true
}

variable "unifi_username" {
  description = "Username for UniFi controller authentication"
  type        = string
  sensitive   = true
}

variable "unifi_password" {
  description = "Password for UniFi controller authentication"
  type        = string
  sensitive   = true
}

variable "unifi_controller_url" {
  description = "URL of the UniFi controller"
  type        = string
}

variable "unifi_site" {
  description = "Site name in UniFi controller"
  type        = string
}

variable "network" {
  description = "Main network configuration"
  type = object({
    name         = string
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    dhcp_enabled = bool
    dhcp_start   = string
    dhcp_stop    = string
  })
}

variable "wan_networks" {
  description = "WAN network configurations"
  type = list(object({
    name     = string
    wan_type = string
    wan_dns1 = string
    wan_dns2 = string
    wan_dns3 = string
    wan_dns4 = string
  }))
}

variable "port_forwards" {
  description = "Port forwarding rules"
  type = list(object({
    name     = string
    protocol = string
    src_port = string
    dst_port = string
    dst_ip   = string
    enabled  = bool
  }))
  default = []
} 