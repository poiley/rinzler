variable "enabled" {
  description = "Whether to enable the Pi-hole module"
  type        = bool
  default     = true
}

terraform {
  required_providers {
    pihole = {
      source  = "ryanwholey/pihole"
      version = "~> 0.2.0"
    }
  }
}

provider "pihole" {
  url       = var.PIHOLE_URL
  api_token = var.PIHOLE_API_TOKEN
}

# DNS Records
resource "pihole_dns_record" "records" {
  for_each = var.ENABLED && var.PIHOLE_URL != "" ? { for r in var.DNS_RECORDS : r.domain => r } : {}

  domain = each.value.domain
  ip     = each.value.ip
} 