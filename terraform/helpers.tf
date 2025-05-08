locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    UNIFI_SITE  = "default"
    REPO_BRANCH = "master"
    REPO_PATH   = "/opt/rinzler"
    ZFS_DATASET = "docker"
    TIMEZONE    = "UTC"
    PUID        = "1000"
    PGID        = "1000"
    RUNNER_NAME = "rinzler-runner"
    RUNNER_DIR  = "/opt/github-runner"
  }
}

# Define a map of all configurable variables
locals {
  variables = {
    UNIFI_CONTROLLER_URL   = var.UNIFI_CONTROLLER_URL
    UNIFI_API_KEY          = var.UNIFI_API_KEY
    PIHOLE_URL             = var.PIHOLE_URL
    PIHOLE_API_TOKEN       = var.PIHOLE_API_TOKEN
    SERVER_HOST            = var.SERVER_HOST
    SSH_USER               = var.SSH_USER
    SSH_PRIVATE_KEY        = var.SSH_PRIVATE_KEY
    REPO_URL               = var.REPO_URL
    ZFS_POOL               = var.ZFS_POOL
    GITHUB_TOKEN           = var.GITHUB_TOKEN
    GITHUB_OWNER           = var.GITHUB_OWNER
    REPOSITORY_NAME        = var.REPOSITORY_NAME
    RUNNER_TOKEN           = var.RUNNER_TOKEN
    UNIFI_USERNAME         = var.UNIFI_USERNAME
    UNIFI_PASSWORD         = var.UNIFI_PASSWORD
    UNIFI_SITE             = var.UNIFI_SITE
    REPO_BRANCH            = var.REPO_BRANCH
    REPO_PATH              = var.REPO_PATH
    ZFS_DATASET            = var.ZFS_DATASET
    DOCKGE_STACKS_DIR      = var.DOCKGE_STACKS_DIR
    WIREGUARD_PRIVATE_KEY  = var.WIREGUARD_PRIVATE_KEY
    WIREGUARD_ADDRESSES    = var.WIREGUARD_ADDRESSES
    PIHOLE_PASSWORD        = var.PIHOLE_PASSWORD
    GITHUB_REPO_NAME       = var.GITHUB_REPO_NAME
    GITHUB_SSH_USER        = var.GITHUB_SSH_USER
    GITHUB_SERVER_HOST     = var.GITHUB_SERVER_HOST
    GITHUB_SSH_PRIVATE_KEY = var.GITHUB_SSH_PRIVATE_KEY
    GITHUB_RUNNER_TOKEN    = var.GITHUB_RUNNER_TOKEN
    BASIC_AUTH_HEADER      = var.BASIC_AUTH_HEADER
    TIMEZONE               = var.TIMEZONE
    PUID                   = var.PUID
    PGID                   = var.PGID
    RUNNER_NAME            = var.RUNNER_NAME
    RUNNER_DIR             = var.RUNNER_DIR
    RUNNER_VERSION         = var.RUNNER_VERSION
    RUNNER_HASH            = var.RUNNER_HASH
    ENVIRONMENT            = var.ENVIRONMENT
  }
}
