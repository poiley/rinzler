# Outputs from UniFi module
output "UNIFI_NETWORKS" {
  description = "Created UniFi networks"
  value       = module.unifi.NETWORKS
}

output "UNIFI_PORT_FORWARDS" {
  description = "Created UniFi port forwards"
  value       = module.unifi.PORT_FORWARDS
}

# Outputs from Pi-hole module
output "PIHOLE_DNS_RECORDS" {
  description = "Created Pi-hole DNS records"
  value       = module.pihole.DNS_RECORDS
}

# Outputs from Bootstrap module
output "BOOTSTRAPPED_SERVER" {
  description = "Details of the bootstrapped server"
  value       = module.bootstrap.SERVER_HOST
}

output "REPOSITORY_PATH" {
  description = "Path where the repository was cloned"
  value       = module.bootstrap.REPO_PATH
}

# Outputs from Runner module
output "GITHUB_RUNNER" {
  description = "Details of the installed GitHub runner"
  value       = module.runner.RUNNER_NAME
}

output "RUNNER_INSTALLATION_PATH" {
  description = "Path where the GitHub runner is installed"
  value       = module.runner.RUNNER_DIR
} 