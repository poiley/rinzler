output "dns_records" {
  description = "Created DNS records"
  value       = pihole_dns_record.records
}

output "pihole_url" {
  description = "URL of the Pi-hole instance"
  value       = var.pihole_url
}

output "pihole_api_token" {
  description = "Pi-hole API token"
  value       = var.pihole_api_token
  sensitive   = true
} 