locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    PIHOLE_URL = ""
  }

  # Define a map of all configurable variables
  variables = {
    PIHOLE_URL       = var.PIHOLE_URL
    PIHOLE_API_TOKEN = var.PIHOLE_API_TOKEN
    PIHOLE_PASSWORD  = var.PIHOLE_PASSWORD
  }

  # Resolved variables for use in the module
  PIHOLE_URL       = local.resolve_var["PIHOLE_URL"]
  PIHOLE_API_TOKEN = local.resolve_var["PIHOLE_API_TOKEN"]
  PIHOLE_PASSWORD  = local.resolve_var["PIHOLE_PASSWORD"]
} 