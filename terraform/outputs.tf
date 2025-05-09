# Outputs from UniFi module
output "unifi_networks" {
  description = "Created UniFi networks"
  value       = module.unifi.networks
}

output "unifi_port_forwards" {
  description = "Created UniFi port forwards"
  value       = module.unifi.port_forwards
}

# Outputs from Pi-hole module
output "dns_records" {
  description = "Created DNS records"
  value       = module.pihole.dns_records
}

# Outputs from Bootstrap module
output "bootstrapped_server" {
  description = "Bootstrapped server hostname"
  value       = module.bootstrap.server_host
}

output "repository_path" {
  description = "Path to repository"
  value       = module.bootstrap.repo_path
}

# Outputs from Runner module
output "github_runner" {
  description = "GitHub runner name"
  value       = module.runner.runner_name
}

output "runner_installation_path" {
  description = "GitHub runner installation path"
  value       = module.runner.runner_dir
} 