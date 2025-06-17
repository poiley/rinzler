variable "rancher_hostname" {
  description = "Hostname for Rancher server"
  type        = string
  default     = "rancher.local"
}

variable "rancher_bootstrap_password" {
  description = "Bootstrap password for Rancher"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificates"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "domain" {
  description = "Base domain for services"
  type        = string
  default     = "local"
}

variable "storage_node_names" {
  description = "List of node names that have local storage"
  type        = list(string)
  default     = ["node1"]
}

variable "vault_dev_mode" {
  description = "Enable Vault development mode (NOT for production)"
  type        = bool
  default     = false
} 