variable "variables" {
  description = "Map of variables to resolve"
  type        = map(string)
  default     = {}
}

variable "defaults" {
  description = "Map of default values for variables"
  type        = map(string)
  default     = {}
}

variable "UNIFI_CONTROLLER_URL" {
  description = "URL of the UniFi controller"
  type        = string
  default     = ""
}

variable "UNIFI_API_KEY" {
  description = "UniFi API key"
  type        = string
  default     = ""
}

variable "PIHOLE_URL" {
  description = "URL of the Pi-hole instance"
  type        = string
  default     = ""
}

variable "PIHOLE_API_TOKEN" {
  description = "Pi-hole API token"
  type        = string
  default     = ""
}

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

variable "REPO_URL" {
  description = "Repository URL to clone"
  type        = string
  default     = ""
}

variable "ZFS_POOL" {
  description = "ZFS pool name"
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

variable "REPO_BRANCH" {
  description = "Repository branch to checkout"
  type        = string
  default     = ""
}

variable "REPO_PATH" {
  description = "Path to repository"
  type        = string
  default     = ""
}

variable "ZFS_DATASET" {
  description = "ZFS dataset name"
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

variable "GITHUB_REPO_NAME" {
  description = "Name of the GitHub repository"
  type        = string
  default     = ""
}

variable "GITHUB_SSH_USER" {
  description = "GitHub SSH user"
  type        = string
  default     = ""
}

variable "GITHUB_SERVER_HOST" {
  description = "GitHub server host"
  type        = string
  default     = ""
}

variable "GITHUB_SSH_PRIVATE_KEY" {
  description = "GitHub SSH private key path"
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

variable "BASIC_AUTH_HEADER" {
  description = "Base64-encoded basic auth header for basic authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "TIMEZONE" {
  description = "Server timezone"
  type        = string
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

variable "RUNNER_NAME" {
  description = "GitHub runner name"
  type        = string
  default     = ""
}

variable "RUNNER_DIR" {
  description = "GitHub runner directory"
  type        = string
  default     = ""
}

variable "RUNNER_VERSION" {
  description = "Version of the GitHub runner to install"
  type        = string
  default     = ""
}

variable "RUNNER_HASH" {
  description = "SHA-256 hash of the runner package for validation"
  type        = string
  default     = ""
}

variable "packages" {
  description = "List of packages to install"
  type        = list(string)
  default     = []
} 