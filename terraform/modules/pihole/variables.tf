variable "PIHOLE_URL" {
  description = "Pi-hole URL"
  type        = string
  default     = ""
}

variable "PIHOLE_API_TOKEN" {
  description = "Pi-hole API token"
  type        = string
  sensitive   = true
}

variable "PIHOLE_PASSWORD" {
  description = "Pi-hole web interface password"
  type        = string
  sensitive   = true
}

variable "ENABLED" {
  description = "Whether to enable Pi-hole configuration"
  type        = bool
  default     = true
}

variable "DNS_RECORDS" {
  description = "List of DNS records to create"
  type = list(object({
    domain  = string
    ip      = string
    comment = optional(string)
  }))
  default = []
} 