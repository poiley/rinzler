locals {
  # Helper function to resolve variables with consistent fallback pattern
  resolve_var = {
    for k, v in local.variables : upper(k) => (
      v != "" ? v : lookup(local.defaults, upper(k), "")
    )
  }

  # Default values for variables
  defaults = {
    RUNNER_NAME    = "rinzler-runner"
    RUNNER_DIR     = "/opt/github-runner"
    RUNNER_VERSION = "2.323.0"
    RUNNER_HASH    = "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19"
  }

  # Define a map of all configurable variables
  variables = {
    SERVER_HOST            = var.SERVER_HOST
    SSH_USER               = var.SSH_USER
    SSH_PRIVATE_KEY        = var.SSH_PRIVATE_KEY
    GITHUB_REPO_NAME       = var.GITHUB_REPO_NAME
    GITHUB_TOKEN           = var.GITHUB_TOKEN
    GITHUB_SSH_USER        = var.GITHUB_SSH_USER
    GITHUB_SERVER_HOST     = var.GITHUB_SERVER_HOST
    GITHUB_SSH_PRIVATE_KEY = var.GITHUB_SSH_PRIVATE_KEY
    GITHUB_RUNNER_TOKEN    = var.GITHUB_RUNNER_TOKEN
    RUNNER_NAME            = var.RUNNER_NAME
    RUNNER_DIR             = var.RUNNER_DIR
    RUNNER_VERSION         = var.RUNNER_VERSION
    RUNNER_HASH            = var.RUNNER_HASH
  }

  # Resolved variables for use in the module
  SERVER_HOST            = local.resolve_var["SERVER_HOST"]
  SSH_USER               = local.resolve_var["SSH_USER"]
  SSH_PRIVATE_KEY        = local.resolve_var["SSH_PRIVATE_KEY"]
  REPOSITORY_NAME        = local.resolve_var["GITHUB_REPO_NAME"]
  GITHUB_TOKEN           = local.resolve_var["GITHUB_TOKEN"]
  GITHUB_SSH_USER        = local.resolve_var["GITHUB_SSH_USER"]
  GITHUB_SERVER_HOST     = local.resolve_var["GITHUB_SERVER_HOST"]
  GITHUB_SSH_PRIVATE_KEY = local.resolve_var["GITHUB_SSH_PRIVATE_KEY"]
  GITHUB_RUNNER_TOKEN    = local.resolve_var["GITHUB_RUNNER_TOKEN"]
  RUNNER_NAME            = local.resolve_var["RUNNER_NAME"]
  RUNNER_DIR             = local.resolve_var["RUNNER_DIR"]
  RUNNER_VERSION         = local.resolve_var["RUNNER_VERSION"]
  RUNNER_HASH            = local.resolve_var["RUNNER_HASH"]
} 