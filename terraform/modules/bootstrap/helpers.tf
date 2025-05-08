locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    REPO_BRANCH = "main"
    REPO_PATH   = "/opt/rinzler"
    ZFS_DATASET = "docker"
    TIMEZONE    = "UTC"
    PUID        = "1000"
    PGID        = "1000"
    PACKAGES    = "docker.io,docker-compose,git,zfsutils-linux"
  }

  # Define a map of all configurable variables
  variables = {
    SERVER_HOST           = var.SERVER_HOST
    SSH_USER              = var.SSH_USER
    SSH_PRIVATE_KEY       = var.SSH_PRIVATE_KEY
    PACKAGES              = join(",", var.PACKAGES)
    REPO_URL              = var.REPO_URL
    REPO_BRANCH           = var.REPO_BRANCH
    REPO_PATH             = var.REPO_PATH
    ZFS_POOL              = var.ZFS_POOL
    ZFS_DATASET           = var.ZFS_DATASET
    GITHUB_TOKEN          = var.GITHUB_TOKEN
    GITHUB_OWNER          = var.GITHUB_OWNER
    REPOSITORY_NAME       = var.REPOSITORY_NAME
    UNIFI_API_KEY         = var.UNIFI_API_KEY
    PIHOLE_API_TOKEN      = var.PIHOLE_API_TOKEN
    RUNNER_TOKEN          = var.RUNNER_TOKEN
    PIHOLE_URL            = var.PIHOLE_URL
    UNIFI_CONTROLLER_URL  = var.UNIFI_CONTROLLER_URL
    UNIFI_USERNAME        = var.UNIFI_USERNAME
    UNIFI_PASSWORD        = var.UNIFI_PASSWORD
    UNIFI_SITE            = var.UNIFI_SITE
    DOCKGE_STACKS_DIR     = var.DOCKGE_STACKS_DIR
    WIREGUARD_PRIVATE_KEY = var.WIREGUARD_PRIVATE_KEY
    WIREGUARD_ADDRESSES   = var.WIREGUARD_ADDRESSES
    PIHOLE_PASSWORD       = var.PIHOLE_PASSWORD
    BASIC_AUTH_HEADER     = var.BASIC_AUTH_HEADER
    TIMEZONE              = var.TIMEZONE
    PUID                  = var.PUID
    PGID                  = var.PGID
  }

  # Resolved variables for use in the module
  SERVER_HOST           = local.resolve_var["SERVER_HOST"]
  SSH_USER              = local.resolve_var["SSH_USER"]
  SSH_PRIVATE_KEY       = local.resolve_var["SSH_PRIVATE_KEY"]
  PACKAGES              = split(",", local.resolve_var["PACKAGES"])
  REPO_URL              = local.resolve_var["REPO_URL"]
  REPO_BRANCH           = local.resolve_var["REPO_BRANCH"]
  REPO_PATH             = local.resolve_var["REPO_PATH"]
  ZFS_POOL              = local.resolve_var["ZFS_POOL"]
  ZFS_DATASET           = local.resolve_var["ZFS_DATASET"]
  GITHUB_TOKEN          = local.resolve_var["GITHUB_TOKEN"]
  GITHUB_OWNER          = local.resolve_var["GITHUB_OWNER"]
  REPOSITORY_NAME       = local.resolve_var["REPOSITORY_NAME"]
  UNIFI_API_KEY         = local.resolve_var["UNIFI_API_KEY"]
  PIHOLE_API_TOKEN      = local.resolve_var["PIHOLE_API_TOKEN"]
  RUNNER_TOKEN          = local.resolve_var["RUNNER_TOKEN"]
  PIHOLE_URL            = local.resolve_var["PIHOLE_URL"]
  UNIFI_CONTROLLER_URL  = local.resolve_var["UNIFI_CONTROLLER_URL"]
  UNIFI_USERNAME        = local.resolve_var["UNIFI_USERNAME"]
  UNIFI_PASSWORD        = local.resolve_var["UNIFI_PASSWORD"]
  UNIFI_SITE            = local.resolve_var["UNIFI_SITE"]
  DOCKGE_STACKS_DIR     = local.resolve_var["DOCKGE_STACKS_DIR"]
  WIREGUARD_PRIVATE_KEY = local.resolve_var["WIREGUARD_PRIVATE_KEY"]
  WIREGUARD_ADDRESSES   = local.resolve_var["WIREGUARD_ADDRESSES"]
  PIHOLE_PASSWORD       = local.resolve_var["PIHOLE_PASSWORD"]
  BASIC_AUTH_HEADER     = local.resolve_var["BASIC_AUTH_HEADER"]
  TIMEZONE              = local.resolve_var["TIMEZONE"]
  PUID                  = local.resolve_var["PUID"]
  PGID                  = local.resolve_var["PGID"]
} 