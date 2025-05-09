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