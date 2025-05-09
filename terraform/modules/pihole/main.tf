terraform {
  required_providers {
    pihole = {
      source  = "ryanwholey/pihole"
      version = "~> 0.2.0"
    }
  }
}

provider "pihole" {
  url       = var.pihole_url
  api_token = var.pihole_api_token
}

# DNS Records
resource "pihole_dns_record" "records" {
  for_each = { for record in var.dns_records : record.domain => record }

  domain = each.value.domain
  ip     = each.value.ip
} 