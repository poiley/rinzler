variable "GITHUB_TOKEN" {
  description = "GitHub API token"
  type        = string
  default     = ""
}

variable "GITHUB_OWNER" {
  description = "GitHub repository owner"
  type        = string
  default     = ""
}

variable "REPOSITORY_NAME" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "UNIFI_API_KEY" {
  description = "UniFi API key"
  type        = string
  default     = ""
}

variable "PIHOLE_API_TOKEN" {
  description = "Pi-hole API token"
  type        = string
  default     = ""
}

variable "RUNNER_TOKEN" {
  description = "GitHub runner token"
  type        = string
  default     = ""
}

variable "SSH_PRIVATE_KEY" {
  description = "SSH private key for runner"
  type        = string
  default     = ""
}

variable "SERVER_HOST" {
  description = "Server hostname or IP address"
  type        = string
  default     = ""
}

variable "SSH_USER" {
  description = "SSH user for runner"
  type        = string
  default     = ""
} 