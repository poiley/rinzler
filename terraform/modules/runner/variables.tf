variable "SERVER_HOST" {
  description = "Hostname or IP of the server to install the runner on"
  type        = string
  default     = ""
}

variable "SSH_USER" {
  description = "SSH user for remote execution"
  type        = string
  default     = ""
}

variable "SSH_PRIVATE_KEY" {
  description = "SSH private key for remote execution"
  type        = string
  sensitive   = true
  default     = ""
}

variable "GITHUB_REPO_NAME" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "GITHUB_TOKEN" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
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

variable "RUNNER_NAME" {
  description = "GitHub runner name"
  type        = string
  default     = "rinzler-runner"
}

variable "RUNNER_DIR" {
  description = "GitHub runner directory"
  type        = string
  default     = "/opt/github-runner"
}

variable "RUNNER_VERSION" {
  description = "Version of the GitHub runner to install"
  type        = string
  default     = "2.323.0"
}

variable "RUNNER_HASH" {
  description = "SHA-256 hash of the runner package for validation"
  type        = string
  default     = "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19"
} 