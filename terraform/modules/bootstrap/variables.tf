variable "SERVER_HOST" {
  description = "Server hostname or IP address"
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

variable "PACKAGES" {
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
  default     = ""
}

variable "REPO_PATH" {
  description = "Path to repository"
  type        = string
  default     = "/opt/rinzler"
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

variable "TIMEZONE" {
  description = "Server timezone"
  type        = string
  default     = "UTC"
}

variable "DOCKER_COMPOSE_VERSION" {
  description = "Docker Compose version to install"
  type        = string
  default     = "v2.24.6"
}

variable "COMPOSE_DIR" {
  description = "Directory containing Docker Compose files"
  type        = string
  default     = ""
}

variable "ZFS_POOL" {
  description = "ZFS pool name"
  type        = string
  default     = ""
}

variable "ZFS_DATASET" {
  description = "ZFS dataset name"
  type        = string
  default     = ""
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

variable "UNIFI_API_KEY" {
  description = "UniFi API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "PIHOLE_API_TOKEN" {
  description = "Pi-hole API token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "RUNNER_TOKEN" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "PIHOLE_URL" {
  description = "URL of the Pi-hole instance"
  type        = string
  default     = ""
}

variable "UNIFI_CONTROLLER_URL" {
  description = "URL of the UniFi controller"
  type        = string
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