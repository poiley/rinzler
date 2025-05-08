locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    GITHUB_OWNER = "poile"
  }

  # Define a map of all configurable variables
  variables = {
    GITHUB_TOKEN     = var.GITHUB_TOKEN
    GITHUB_OWNER     = var.GITHUB_OWNER
    REPOSITORY_NAME  = var.REPOSITORY_NAME
    UNIFI_API_KEY    = var.UNIFI_API_KEY
    PIHOLE_API_TOKEN = var.PIHOLE_API_TOKEN
    RUNNER_TOKEN     = var.RUNNER_TOKEN
    SSH_PRIVATE_KEY  = var.SSH_PRIVATE_KEY
    SERVER_HOST      = var.SERVER_HOST
    SSH_USER         = var.SSH_USER
  }

  # Resolved variables for use in the module
  GITHUB_TOKEN     = local.resolve_var["GITHUB_TOKEN"]
  GITHUB_OWNER     = local.resolve_var["GITHUB_OWNER"]
  REPOSITORY_NAME  = local.resolve_var["REPOSITORY_NAME"]
  UNIFI_API_KEY    = local.resolve_var["UNIFI_API_KEY"]
  PIHOLE_API_TOKEN = local.resolve_var["PIHOLE_API_TOKEN"]
  RUNNER_TOKEN     = local.resolve_var["RUNNER_TOKEN"]
  SSH_PRIVATE_KEY  = local.resolve_var["SSH_PRIVATE_KEY"]
  SERVER_HOST      = local.resolve_var["SERVER_HOST"]
  SSH_USER         = local.resolve_var["SSH_USER"]
} 