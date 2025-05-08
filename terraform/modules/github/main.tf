terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.GITHUB_TOKEN
  owner = var.GITHUB_OWNER
}

# GitHub Secrets
resource "github_actions_secret" "unifi_api_key" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "UNIFI_API_KEY"
  plaintext_value = var.UNIFI_API_KEY
}

resource "github_actions_secret" "pihole_api_token" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "PIHOLE_API_TOKEN"
  plaintext_value = var.PIHOLE_API_TOKEN
}

resource "github_actions_secret" "runner_token" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "RUNNER_TOKEN"
  plaintext_value = var.RUNNER_TOKEN
}

resource "github_actions_secret" "ssh_private_key" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "SSH_PRIVATE_KEY"
  plaintext_value = var.SSH_PRIVATE_KEY
}

resource "github_actions_secret" "server_host" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "SERVER_HOST"
  plaintext_value = var.SERVER_HOST
}

resource "github_actions_secret" "ssh_user" {
  repository      = var.REPOSITORY_NAME
  secret_name     = "SSH_USER"
  plaintext_value = var.SSH_USER
} 