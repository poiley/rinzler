variable "UNIFI_CONTROLLER_URL" {
  description = "URL of the UniFi controller"
  type        = string
}

variable "UNIFI_USERNAME" {
  description = "Username for the UniFi controller"
  type        = string
}

variable "UNIFI_PASSWORD" {
  description = "Password for the UniFi controller"
  type        = string
  sensitive   = true
}

variable "UNIFI_API_KEY" {
  description = "API key for the UniFi controller"
  type        = string
  sensitive   = true
}

variable "UNIFI_SITE" {
  description = "Name of the UniFi site"
  type        = string
  default     = "default"
}

variable "NETWORK" {
  description = "Main network configuration"
  type = object({
    name         = string
    subnet       = string
    dhcp_enabled = bool
    dhcp_start   = string
    dhcp_stop    = string
    dns_servers  = list(string)
  })
}

variable "WAN_NETWORKS" {
  description = "List of WAN network configurations"
  type = list(object({
    name     = string
    wan_type = string
    wan_dns1 = string
    wan_dns2 = string
    wan_dns3 = string
    wan_dns4 = string
  }))
  default = []
}

variable "PORT_FORWARDS" {
  description = "List of port forwarding rules"
  type = list(object({
    name     = string
    protocol = string
    dst_port = number
    dst_ip   = string
    enabled  = bool
  }))
  default = []
} 