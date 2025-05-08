variable "UNIFI_CONTROLLER_URL" {
  description = "URL of the UniFi controller (e.g., https://cloudkey.lan)"
  type        = string
}

variable "UNIFI_API_KEY" {
  description = "API key for UniFi controller"
  type        = string
  sensitive   = true
}

variable "NETWORK" {
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

variable "WAN_NETWORKS" {
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

variable "PORT_FORWARDS" {
  description = "Port forwarding rules"
  type = list(object({
    name     = string
    protocol = string
    src_port = string
    dst_port = string
    dst_ip   = string
    enabled  = bool
  }))
  default = []
}

variable "PIHOLE_URL" {
  description = "URL of the Pi-hole instance (e.g., http://192.168.1.227/admin)"
  type        = string
}

variable "PIHOLE_API_TOKEN" {
  description = "API token for Pi-hole"
  type        = string
  sensitive   = true
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

# Bootstrap Variables
variable "SERVER_HOST" {
  description = "Hostname or IP of the server"
  type        = string
  default     = ""
}

variable "SSH_USER" {
  description = "SSH user for server access"
  type        = string
  default     = ""
}

variable "SSH_PRIVATE_KEY" {
  description = "SSH private key for server access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "packages" {
  description = "List of packages to install"
  type        = list(string)
  default     = []
}

variable "REPO_URL" {
  description = "Repository URL to clone"
  type        = string
  default     = ""
}

variable "REPO_BRANCH" {
  description = "Repository branch to checkout"
  type        = string
  default     = "master"
}

variable "REPO_PATH" {
  description = "Path to clone repository"
  type        = string
  default     = ""
}

variable "ENV_VARS" {
  description = "Environment variables to set"
  type        = map(string)
  default     = {}
}

variable "COMPOSE_FILES" {
  description = "List of compose files to use"
  type        = list(string)
  default     = []
}

variable "ZFS_POOL" {
  description = "ZFS pool name"
  type        = string
  default     = ""
}

variable "ZFS_DATASET" {
  description = "ZFS dataset name for docker data"
  type        = string
  default     = ""
}

variable "GITHUB_TOKEN" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "GITHUB_OWNER" {
  description = "GitHub organization or user name"
  type        = string
  default     = ""
}

variable "REPOSITORY_NAME" {
  description = "Name of the GitHub repository"
  type        = string
  default     = ""
}

variable "RUNNER_TOKEN" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "UNIFI_USERNAME" {
  description = "Username for UniFi controller authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "UNIFI_PASSWORD" {
  description = "Password for UniFi controller authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "UNIFI_SITE" {
  description = "Site name in UniFi controller"
  type        = string
  default     = ""
}

variable "DOCKGE_STACKS_DIR" {
  description = "Directory for Dockge stacks"
  type        = string
  default     = ""
}

variable "WIREGUARD_PRIVATE_KEY" {
  description = "Wireguard private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "WIREGUARD_ADDRESSES" {
  description = "Wireguard addresses"
  type        = string
  default     = ""
}

variable "PIHOLE_PASSWORD" {
  description = "Password for Pi-hole web UI"
  type        = string
  sensitive   = true
  default     = ""
}

variable "BASIC_AUTH_HEADER" {
  description = "Base64-encoded basic auth header for basic authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "PUID" {
  description = "User ID for Docker containers"
  type        = string
  default     = ""
}

variable "PGID" {
  description = "Group ID for Docker containers"
  type        = string
  default     = ""
}

variable "TIMEZONE" {
  description = "Server timezone"
  type        = string
  default     = ""
}

variable "RUNNER_NAME" {
  description = "Name of the GitHub runner"
  type        = string
  default     = ""
}

variable "RUNNER_DIR" {
  description = "Directory for GitHub runner"
  type        = string
  default     = "/opt/github-runner"
}

variable "RUNNER_VERSION" {
  description = "Version of GitHub runner to install"
  type        = string
  default     = "2.314.1"
}

variable "RUNNER_HASH" {
  description = "Hash of the GitHub runner package"
  type        = string
  default     = "f4c3af8df563b5a16ea14aba6c13c5c23b5d78a1"
}

variable "GITHUB_REPO_NAME" {
  description = "Name of the GitHub repository"
  type        = string
  default     = ""
}

variable "GITHUB_SSH_USER" {
  description = "SSH user for GitHub runner"
  type        = string
  default     = ""
}

variable "GITHUB_SERVER_HOST" {
  description = "Server host for GitHub runner"
  type        = string
  default     = ""
}

variable "GITHUB_SSH_PRIVATE_KEY" {
  description = "SSH private key for GitHub runner"
  type        = string
  sensitive   = true
  default     = ""
}

variable "GITHUB_RUNNER_TOKEN" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ENVIRONMENT" {
  description = "Environment name (e.g., test, prod)"
  type        = string
  default     = "test"
}

variable "PACKAGES" {
  description = "List of packages to install"
  type        = list(string)
  default     = []
}

variable "NETWORK_GATEWAY" {
  description = "Gateway IP for the main network"
  type        = string
  default     = ""
}

variable "NETWORK_DNS_SERVERS" {
  description = "List of DNS servers for the main network"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
  default     = "test"
}
