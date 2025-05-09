variable "pihole_url" {
  description = "URL of the Pi-hole instance"
  type        = string
}

variable "pihole_api_token" {
  description = "Pi-hole API token"
  type        = string
  sensitive   = true
}

variable "dns_records" {
  description = "List of DNS records to create"
  type = list(object({
    domain  = string
    ip      = string
    comment = optional(string)
  }))
  default = []
}

variable "pihole_password" {
  description = "Password for Pi-hole web UI"
  type        = string
  sensitive   = true
}

variable "enabled" {
  description = "Whether to enable Pi-hole configuration"
  type        = bool
  default     = true
} 