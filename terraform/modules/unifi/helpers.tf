locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    UNIFI_SITE = "default"
  }

  # Define a map of all configurable variables
  variables = {
    UNIFI_CONTROLLER_URL = var.UNIFI_CONTROLLER_URL
    UNIFI_USERNAME       = var.UNIFI_USERNAME
    UNIFI_PASSWORD       = var.UNIFI_PASSWORD
    UNIFI_API_KEY        = var.UNIFI_API_KEY
    UNIFI_SITE           = var.UNIFI_SITE
  }

  # Resolved variables for use in the module
  UNIFI_CONTROLLER_URL = local.resolve_var["UNIFI_CONTROLLER_URL"]
  UNIFI_USERNAME       = local.resolve_var["UNIFI_USERNAME"]
  UNIFI_PASSWORD       = local.resolve_var["UNIFI_PASSWORD"]
  UNIFI_API_KEY        = local.resolve_var["UNIFI_API_KEY"]
  UNIFI_SITE           = local.resolve_var["UNIFI_SITE"]
} 