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
  default     = []
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
  description = "Environment variables to set"
  type        = map(string)
  default     = {}
}

variable "timezone" {
  description = "Server timezone"
  type        = string
}

variable "docker_compose_version" {
  description = "Docker Compose version to install"
  type        = string
  default     = "v2.24.6"
}

variable "compose_dir" {
  description = "Directory containing Docker Compose files"
  type        = string
  default     = ""
}

variable "zfs_pool" {
  description = "ZFS pool name"
  type        = string
}

variable "zfs_dataset" {
  description = "ZFS dataset name"
  type        = string
}

variable "wan_networks" {
  description = "WAN network configurations"
  type        = list(map(any))
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

variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "unifi_api_key" {
  description = "UniFi API key"
  type        = string
  sensitive   = true
}

variable "pihole_api_token" {
  description = "Pi-hole API token"
  type        = string
  sensitive   = true
}

variable "runner_token" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
}

variable "pihole_url" {
  description = "URL of the Pi-hole instance"
  type        = string
}

variable "unifi_controller_url" {
  description = "URL of the UniFi controller"
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

variable "zfs_disk_path" {
  description = "Path to the disk to use for ZFS pool"
  type        = string
  default     = "/dev/sdb"
} 