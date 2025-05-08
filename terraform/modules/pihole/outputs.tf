output "DNS_RECORDS" {
  description = "Created DNS records"
  value       = pihole_dns_record.records
}

output "PIHOLE_URL" {
  description = "URL of the Pi-hole instance"
  value       = var.PIHOLE_URL
}

output "PIHOLE_API_TOKEN" {
  description = "API token for Pi-hole"
  value       = var.PIHOLE_API_TOKEN
} 