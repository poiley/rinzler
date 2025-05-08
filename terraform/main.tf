locals {
  # Use the resolved variables from our helper
  UNIFI_CONTROLLER_URL   = local.resolve_var["UNIFI_CONTROLLER_URL"]
  UNIFI_API_KEY          = local.resolve_var["UNIFI_API_KEY"]
  PIHOLE_URL             = local.resolve_var["PIHOLE_URL"]
  PIHOLE_API_TOKEN       = local.resolve_var["PIHOLE_API_TOKEN"]
  SERVER_HOST            = local.resolve_var["SERVER_HOST"]
  SSH_USER               = local.resolve_var["SSH_USER"]
  SSH_PRIVATE_KEY        = local.resolve_var["SSH_PRIVATE_KEY"]
  REPO_URL               = local.resolve_var["REPO_URL"]
  ZFS_POOL               = local.resolve_var["ZFS_POOL"]
  GITHUB_TOKEN           = local.resolve_var["GITHUB_TOKEN"]
  GITHUB_OWNER           = local.resolve_var["GITHUB_OWNER"]
  REPOSITORY_NAME        = local.resolve_var["REPOSITORY_NAME"]
  RUNNER_TOKEN           = local.resolve_var["RUNNER_TOKEN"]
  UNIFI_USERNAME         = local.resolve_var["UNIFI_USERNAME"]
  UNIFI_PASSWORD         = local.resolve_var["UNIFI_PASSWORD"]
  UNIFI_SITE             = local.resolve_var["UNIFI_SITE"]
  REPO_BRANCH            = local.resolve_var["REPO_BRANCH"]
  REPO_PATH              = local.resolve_var["REPO_PATH"]
  ZFS_DATASET            = local.resolve_var["ZFS_DATASET"]
  DOCKGE_STACKS_DIR      = local.resolve_var["DOCKGE_STACKS_DIR"]
  WIREGUARD_PRIVATE_KEY  = local.resolve_var["WIREGUARD_PRIVATE_KEY"]
  WIREGUARD_ADDRESSES    = local.resolve_var["WIREGUARD_ADDRESSES"]
  PIHOLE_PASSWORD        = local.resolve_var["PIHOLE_PASSWORD"]
  GITHUB_REPO_NAME       = local.resolve_var["GITHUB_REPO_NAME"]
  GITHUB_SSH_USER        = local.resolve_var["GITHUB_SSH_USER"]
  GITHUB_SERVER_HOST     = local.resolve_var["GITHUB_SERVER_HOST"]
  GITHUB_SSH_PRIVATE_KEY = local.resolve_var["GITHUB_SSH_PRIVATE_KEY"]
  GITHUB_RUNNER_TOKEN    = local.resolve_var["GITHUB_RUNNER_TOKEN"]
  BASIC_AUTH_HEADER      = local.resolve_var["BASIC_AUTH_HEADER"]
  TIMEZONE               = local.resolve_var["TIMEZONE"]
  PUID                   = local.resolve_var["PUID"]
  PGID                   = local.resolve_var["PGID"]
  RUNNER_NAME            = local.resolve_var["RUNNER_NAME"]
  RUNNER_DIR             = local.resolve_var["RUNNER_DIR"]
  RUNNER_VERSION         = local.resolve_var["RUNNER_VERSION"]
  RUNNER_HASH            = local.resolve_var["RUNNER_HASH"]

  # Special handling for packages list
  packages = length(var.packages) > 0 ? var.packages : try(split(",", getenv("PACKAGES")), ["docker.io", "docker-compose", "git", "zfsutils-linux"])
}

terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.41.0"
    }
    pihole = {
      source  = "ryanwholey/pihole"
      version = "~> 0.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "unifi" {
  username       = local.UNIFI_USERNAME
  password       = local.UNIFI_PASSWORD
  api_url        = local.UNIFI_CONTROLLER_URL
  allow_insecure = true
}

provider "pihole" {
  url       = local.PIHOLE_URL
  api_token = local.PIHOLE_API_TOKEN
}

provider "docker" {}

# GitHub Secrets Management
module "github" {
  source = "./modules/github"

  GITHUB_TOKEN     = local.GITHUB_TOKEN
  GITHUB_OWNER     = local.GITHUB_OWNER
  REPOSITORY_NAME  = local.REPOSITORY_NAME
  UNIFI_API_KEY    = local.UNIFI_API_KEY
  PIHOLE_API_TOKEN = local.PIHOLE_API_TOKEN
  RUNNER_TOKEN     = local.RUNNER_TOKEN
  SSH_PRIVATE_KEY  = local.SSH_PRIVATE_KEY
  SERVER_HOST      = local.SERVER_HOST
  SSH_USER         = local.SSH_USER
}

# UniFi Network Configuration
module "unifi" {
  source               = "./modules/unifi"
  UNIFI_API_KEY        = local.UNIFI_API_KEY
  UNIFI_CONTROLLER_URL = local.UNIFI_CONTROLLER_URL
  UNIFI_USERNAME       = local.UNIFI_USERNAME
  UNIFI_PASSWORD       = local.UNIFI_PASSWORD
  UNIFI_SITE           = local.UNIFI_SITE
  NETWORK              = var.NETWORK
  WAN_NETWORKS         = var.WAN_NETWORKS
  PORT_FORWARDS        = var.PORT_FORWARDS
}

# Pi-hole DNS Configuration
module "pihole" {
  source           = "./modules/pihole"
  PIHOLE_URL       = local.PIHOLE_URL
  PIHOLE_API_TOKEN = local.PIHOLE_API_TOKEN
  DNS_RECORDS      = var.DNS_RECORDS
  PIHOLE_PASSWORD  = local.PIHOLE_PASSWORD
}

# Server Bootstrap Configuration
module "bootstrap" {
  source = "./modules/bootstrap"

  SERVER_HOST           = local.SERVER_HOST
  SSH_USER              = local.SSH_USER
  SSH_PRIVATE_KEY       = local.SSH_PRIVATE_KEY
  PACKAGES              = local.packages
  REPO_URL              = local.REPO_URL
  REPO_BRANCH           = local.REPO_BRANCH
  REPO_PATH             = local.REPO_PATH
  ENV_VARS              = var.ENV_VARS
  COMPOSE_FILES         = var.COMPOSE_FILES
  ZFS_POOL              = local.ZFS_POOL
  ZFS_DATASET           = local.ZFS_DATASET
  GITHUB_TOKEN          = local.GITHUB_TOKEN
  GITHUB_OWNER          = local.GITHUB_OWNER
  REPOSITORY_NAME       = local.REPOSITORY_NAME
  UNIFI_API_KEY         = local.UNIFI_API_KEY
  PIHOLE_API_TOKEN      = local.PIHOLE_API_TOKEN
  RUNNER_TOKEN          = local.RUNNER_TOKEN
  PIHOLE_URL            = local.PIHOLE_URL
  UNIFI_CONTROLLER_URL  = local.UNIFI_CONTROLLER_URL
  UNIFI_USERNAME        = local.UNIFI_USERNAME
  UNIFI_PASSWORD        = local.UNIFI_PASSWORD
  UNIFI_SITE            = local.UNIFI_SITE
  DOCKGE_STACKS_DIR     = local.DOCKGE_STACKS_DIR
  WIREGUARD_PRIVATE_KEY = local.WIREGUARD_PRIVATE_KEY
  WIREGUARD_ADDRESSES   = local.WIREGUARD_ADDRESSES
  PIHOLE_PASSWORD       = local.PIHOLE_PASSWORD
  BASIC_AUTH_HEADER     = local.BASIC_AUTH_HEADER
  PUID                  = local.PUID
  PGID                  = local.PGID
  WAN_NETWORKS          = var.WAN_NETWORKS
}

# GitHub Runner Configuration
module "runner" {
  source                 = "./modules/runner"
  SERVER_HOST            = local.GITHUB_SERVER_HOST
  SSH_USER               = local.GITHUB_SSH_USER
  SSH_PRIVATE_KEY        = local.GITHUB_SSH_PRIVATE_KEY
  GITHUB_REPO_NAME       = local.GITHUB_REPO_NAME
  GITHUB_TOKEN           = local.GITHUB_TOKEN
  GITHUB_SSH_USER        = local.GITHUB_SSH_USER
  GITHUB_SERVER_HOST     = local.GITHUB_SERVER_HOST
  GITHUB_SSH_PRIVATE_KEY = local.GITHUB_SSH_PRIVATE_KEY
  GITHUB_RUNNER_TOKEN    = local.GITHUB_RUNNER_TOKEN
  RUNNER_NAME            = local.RUNNER_NAME
  RUNNER_DIR             = local.RUNNER_DIR
  RUNNER_VERSION         = local.RUNNER_VERSION
  RUNNER_HASH            = local.RUNNER_HASH
}