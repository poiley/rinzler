variable "unifi_controller_url" {
  description = "URL of the UniFi controller"
  type        = string
}

variable "unifi_api_key" {
  description = "UniFi API key"
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
}

variable "pihole_url" {
  description = "URL of the Pi-hole instance"
  type        = string
}

variable "pihole_api_token" {
  description = "Pi-hole API token"
  type        = string
}

variable "dns_records" {
  description = "List of DNS records to create"
  type = list(object({
    domain  = string
    ip      = string
    comment = optional(string)
  }))
}

# Bootstrap Variables
variable "server_host" {
  description = "Server hostname or IP address"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for server access"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key for server access"
  type        = string
  sensitive   = true
}

variable "packages" {
  description = "List of packages to install"
  type        = list(string)
}

variable "repo_url" {
  description = "Repository URL to clone"
  type        = string
}

variable "repo_branch" {
  description = "Repository branch to checkout"
  type        = string
}

variable "repo_path" {
  description = "Path to repository"
  type        = string
}

variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
}

variable "zfs_pool" {
  description = "ZFS pool name"
  type        = string
}

variable "zfs_dataset" {
  description = "ZFS dataset name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
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

variable "unifi_site" {
  description = "Site name in UniFi controller"
  type        = string
}

variable "dockge_stacks_dir" {
  description = "Directory for Dockge stacks"
  type        = string
}

variable "wireguard_private_key" {
  description = "Wireguard private key"
  type        = string
  sensitive   = true
}

variable "wireguard_addresses" {
  description = "Wireguard addresses"
  type        = string
}

variable "pihole_password" {
  description = "Password for Pi-hole web UI"
  type        = string
  sensitive   = true
}

variable "basic_auth_header" {
  description = "Base64-encoded basic auth header for basic authentication"
  type        = string
  sensitive   = true
}

variable "puid" {
  description = "User ID for Docker containers"
  type        = string
}

variable "pgid" {
  description = "Group ID for Docker containers"
  type        = string
}

variable "timezone" {
  description = "Server timezone"
  type        = string
}

variable "runner_name" {
  description = "GitHub runner name"
  type        = string
}

variable "runner_dir" {
  description = "GitHub runner directory"
  type        = string
}

variable "runner_version" {
  description = "Version of the GitHub runner to install"
  type        = string
}

variable "runner_hash" {
  description = "SHA-256 hash of the runner package for validation"
  type        = string
}

variable "github_repo_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "github_ssh_user" {
  description = "GitHub SSH user"
  type        = string
}

variable "github_server_host" {
  description = "GitHub server host"
  type        = string
}

variable "github_ssh_private_key" {
  description = "GitHub SSH private key"
  type        = string
  sensitive   = true
}

variable "github_runner_token" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "network_gateway" {
  description = "Gateway IP for the main network"
  type        = string
}

variable "network_dns_servers" {
  description = "List of DNS servers for the main network"
  type        = list(string)
}
