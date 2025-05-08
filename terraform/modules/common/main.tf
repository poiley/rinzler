terraform {
  required_version = ">= 1.0.0"
}

locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    UNIFI_CONTROLLER_URL   = var.UNIFI_CONTROLLER_URL != "" ? var.UNIFI_CONTROLLER_URL : lookup(local.defaults, "UNIFI_CONTROLLER_URL", "")
    UNIFI_API_KEY          = var.UNIFI_API_KEY != "" ? var.UNIFI_API_KEY : lookup(local.defaults, "UNIFI_API_KEY", "")
    PIHOLE_URL             = var.PIHOLE_URL != "" ? var.PIHOLE_URL : lookup(local.defaults, "PIHOLE_URL", "")
    PIHOLE_API_TOKEN       = var.PIHOLE_API_TOKEN != "" ? var.PIHOLE_API_TOKEN : lookup(local.defaults, "PIHOLE_API_TOKEN", "")
    SERVER_HOST            = var.SERVER_HOST != "" ? var.SERVER_HOST : lookup(local.defaults, "SERVER_HOST", "")
    SSH_USER               = var.SSH_USER != "" ? var.SSH_USER : lookup(local.defaults, "SSH_USER", "")
    SSH_PRIVATE_KEY        = var.SSH_PRIVATE_KEY != "" ? var.SSH_PRIVATE_KEY : lookup(local.defaults, "SSH_PRIVATE_KEY", "")
    REPO_URL               = var.REPO_URL != "" ? var.REPO_URL : lookup(local.defaults, "REPO_URL", "")
    ZFS_POOL               = var.ZFS_POOL != "" ? var.ZFS_POOL : lookup(local.defaults, "ZFS_POOL", "")
    GITHUB_TOKEN           = var.GITHUB_TOKEN != "" ? var.GITHUB_TOKEN : lookup(local.defaults, "GITHUB_TOKEN", "")
    GITHUB_OWNER           = var.GITHUB_OWNER != "" ? var.GITHUB_OWNER : lookup(local.defaults, "GITHUB_OWNER", "")
    REPOSITORY_NAME        = var.REPOSITORY_NAME != "" ? var.REPOSITORY_NAME : lookup(local.defaults, "REPOSITORY_NAME", "")
    RUNNER_TOKEN           = var.RUNNER_TOKEN != "" ? var.RUNNER_TOKEN : lookup(local.defaults, "RUNNER_TOKEN", "")
    UNIFI_USERNAME         = var.UNIFI_USERNAME != "" ? var.UNIFI_USERNAME : lookup(local.defaults, "UNIFI_USERNAME", "")
    UNIFI_PASSWORD         = var.UNIFI_PASSWORD != "" ? var.UNIFI_PASSWORD : lookup(local.defaults, "UNIFI_PASSWORD", "")
    UNIFI_SITE             = var.UNIFI_SITE != "" ? var.UNIFI_SITE : lookup(local.defaults, "UNIFI_SITE", "")
    REPO_BRANCH            = var.REPO_BRANCH != "" ? var.REPO_BRANCH : lookup(local.defaults, "REPO_BRANCH", "")
    REPO_PATH              = var.REPO_PATH != "" ? var.REPO_PATH : lookup(local.defaults, "REPO_PATH", "")
    ZFS_DATASET            = var.ZFS_DATASET != "" ? var.ZFS_DATASET : lookup(local.defaults, "ZFS_DATASET", "")
    DOCKGE_STACKS_DIR      = var.DOCKGE_STACKS_DIR != "" ? var.DOCKGE_STACKS_DIR : lookup(local.defaults, "DOCKGE_STACKS_DIR", "")
    WIREGUARD_PRIVATE_KEY  = var.WIREGUARD_PRIVATE_KEY != "" ? var.WIREGUARD_PRIVATE_KEY : lookup(local.defaults, "WIREGUARD_PRIVATE_KEY", "")
    WIREGUARD_ADDRESSES    = var.WIREGUARD_ADDRESSES != "" ? var.WIREGUARD_ADDRESSES : lookup(local.defaults, "WIREGUARD_ADDRESSES", "")
    PIHOLE_PASSWORD        = var.PIHOLE_PASSWORD != "" ? var.PIHOLE_PASSWORD : lookup(local.defaults, "PIHOLE_PASSWORD", "")
    GITHUB_REPO_NAME       = var.GITHUB_REPO_NAME != "" ? var.GITHUB_REPO_NAME : lookup(local.defaults, "GITHUB_REPO_NAME", "")
    GITHUB_SSH_USER        = var.GITHUB_SSH_USER != "" ? var.GITHUB_SSH_USER : lookup(local.defaults, "GITHUB_SSH_USER", "")
    GITHUB_SERVER_HOST     = var.GITHUB_SERVER_HOST != "" ? var.GITHUB_SERVER_HOST : lookup(local.defaults, "GITHUB_SERVER_HOST", "")
    GITHUB_SSH_PRIVATE_KEY = var.GITHUB_SSH_PRIVATE_KEY != "" ? var.GITHUB_SSH_PRIVATE_KEY : lookup(local.defaults, "GITHUB_SSH_PRIVATE_KEY", "")
    GITHUB_RUNNER_TOKEN    = var.GITHUB_RUNNER_TOKEN != "" ? var.GITHUB_RUNNER_TOKEN : lookup(local.defaults, "GITHUB_RUNNER_TOKEN", "")
    BASIC_AUTH_HEADER      = var.BASIC_AUTH_HEADER != "" ? var.BASIC_AUTH_HEADER : lookup(local.defaults, "BASIC_AUTH_HEADER", "")
    TIMEZONE               = var.TIMEZONE != "" ? var.TIMEZONE : lookup(local.defaults, "TIMEZONE", "")
    PUID                   = var.PUID != "" ? var.PUID : lookup(local.defaults, "PUID", "")
    PGID                   = var.PGID != "" ? var.PGID : lookup(local.defaults, "PGID", "")
    RUNNER_NAME            = var.RUNNER_NAME != "" ? var.RUNNER_NAME : lookup(local.defaults, "RUNNER_NAME", "")
    RUNNER_DIR             = var.RUNNER_DIR != "" ? var.RUNNER_DIR : lookup(local.defaults, "RUNNER_DIR", "")
    RUNNER_VERSION         = var.RUNNER_VERSION != "" ? var.RUNNER_VERSION : lookup(local.defaults, "RUNNER_VERSION", "")
    RUNNER_HASH            = var.RUNNER_HASH != "" ? var.RUNNER_HASH : lookup(local.defaults, "RUNNER_HASH", "")
  }

  # Default values for variables
  defaults = {
    UNIFI_SITE     = "default"
    REPO_BRANCH    = "main"
    REPO_PATH      = "/opt/rinzler"
    ZFS_DATASET    = "docker"
    TIMEZONE       = "UTC"
    PUID           = "1000"
    PGID           = "1000"
    RUNNER_NAME    = "rinzler-runner"
    RUNNER_DIR     = "/opt/github-runner"
    RUNNER_VERSION = "2.323.0"
    RUNNER_HASH    = "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19"
  }

  # Special handling for packages list
  packages = length(var.packages) > 0 ? var.packages : try(split(",", getenv("PACKAGES")), ["docker.io", "docker-compose", "git", "zfsutils-linux"])
}

output "resolved_variables" {
  description = "Map of resolved variables with their values"
  value       = local.resolve_var
  sensitive   = true
}

output "packages" {
  description = "List of packages to install"
  value       = local.packages
} 