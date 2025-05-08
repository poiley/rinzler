# Common module for variable resolution
module "common" {
  source = "./modules/common"

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
  packages               = var.packages
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
  username       = module.common.resolved_variables["UNIFI_USERNAME"]
  password       = module.common.resolved_variables["UNIFI_PASSWORD"]
  api_url        = module.common.resolved_variables["UNIFI_CONTROLLER_URL"]
  allow_insecure = true
}

provider "pihole" {
  url       = module.common.resolved_variables["PIHOLE_URL"]
  api_token = module.common.resolved_variables["PIHOLE_API_TOKEN"]
}

provider "docker" {}

# GitHub Secrets Management
module "github" {
  source = "./modules/github"

  GITHUB_TOKEN     = module.common.resolved_variables["GITHUB_TOKEN"]
  GITHUB_OWNER     = module.common.resolved_variables["GITHUB_OWNER"]
  REPOSITORY_NAME  = module.common.resolved_variables["REPOSITORY_NAME"]
  UNIFI_API_KEY    = module.common.resolved_variables["UNIFI_API_KEY"]
  PIHOLE_API_TOKEN = module.common.resolved_variables["PIHOLE_API_TOKEN"]
  RUNNER_TOKEN     = module.common.resolved_variables["RUNNER_TOKEN"]
  SSH_PRIVATE_KEY  = module.common.resolved_variables["SSH_PRIVATE_KEY"]
  SERVER_HOST      = module.common.resolved_variables["SERVER_HOST"]
  SSH_USER         = module.common.resolved_variables["SSH_USER"]
}

# UniFi Network Configuration
module "unifi" {
  source               = "./modules/unifi"
  UNIFI_API_KEY        = module.common.resolved_variables["UNIFI_API_KEY"]
  UNIFI_CONTROLLER_URL = module.common.resolved_variables["UNIFI_CONTROLLER_URL"]
  UNIFI_USERNAME       = module.common.resolved_variables["UNIFI_USERNAME"]
  UNIFI_PASSWORD       = module.common.resolved_variables["UNIFI_PASSWORD"]
  UNIFI_SITE           = module.common.resolved_variables["UNIFI_SITE"]
  NETWORK              = var.NETWORK
  WAN_NETWORKS         = var.WAN_NETWORKS
  PORT_FORWARDS        = var.PORT_FORWARDS
}

# Pi-hole DNS Configuration
module "pihole" {
  source           = "./modules/pihole"
  PIHOLE_URL       = module.common.resolved_variables["PIHOLE_URL"]
  PIHOLE_API_TOKEN = module.common.resolved_variables["PIHOLE_API_TOKEN"]
  DNS_RECORDS      = var.DNS_RECORDS
  PIHOLE_PASSWORD  = module.common.resolved_variables["PIHOLE_PASSWORD"]
}

# Server Bootstrap Configuration
module "bootstrap" {
  source = "./modules/bootstrap"

  SERVER_HOST           = module.common.resolved_variables["SERVER_HOST"]
  SSH_USER              = module.common.resolved_variables["SSH_USER"]
  SSH_PRIVATE_KEY       = module.common.resolved_variables["SSH_PRIVATE_KEY"]
  PACKAGES              = module.common.packages
  REPO_URL              = module.common.resolved_variables["REPO_URL"]
  REPO_BRANCH           = module.common.resolved_variables["REPO_BRANCH"]
  REPO_PATH             = module.common.resolved_variables["REPO_PATH"]
  ENV_VARS              = var.ENV_VARS
  COMPOSE_FILES         = var.COMPOSE_FILES
  ZFS_POOL              = module.common.resolved_variables["ZFS_POOL"]
  ZFS_DATASET           = module.common.resolved_variables["ZFS_DATASET"]
  GITHUB_TOKEN          = module.common.resolved_variables["GITHUB_TOKEN"]
  GITHUB_OWNER          = module.common.resolved_variables["GITHUB_OWNER"]
  REPOSITORY_NAME       = module.common.resolved_variables["REPOSITORY_NAME"]
  UNIFI_API_KEY         = module.common.resolved_variables["UNIFI_API_KEY"]
  PIHOLE_API_TOKEN      = module.common.resolved_variables["PIHOLE_API_TOKEN"]
  RUNNER_TOKEN          = module.common.resolved_variables["RUNNER_TOKEN"]
  PIHOLE_URL            = module.common.resolved_variables["PIHOLE_URL"]
  UNIFI_CONTROLLER_URL  = module.common.resolved_variables["UNIFI_CONTROLLER_URL"]
  UNIFI_USERNAME        = module.common.resolved_variables["UNIFI_USERNAME"]
  UNIFI_PASSWORD        = module.common.resolved_variables["UNIFI_PASSWORD"]
  UNIFI_SITE            = module.common.resolved_variables["UNIFI_SITE"]
  DOCKGE_STACKS_DIR     = module.common.resolved_variables["DOCKGE_STACKS_DIR"]
  WIREGUARD_PRIVATE_KEY = module.common.resolved_variables["WIREGUARD_PRIVATE_KEY"]
  WIREGUARD_ADDRESSES   = module.common.resolved_variables["WIREGUARD_ADDRESSES"]
  PIHOLE_PASSWORD       = module.common.resolved_variables["PIHOLE_PASSWORD"]
  BASIC_AUTH_HEADER     = module.common.resolved_variables["BASIC_AUTH_HEADER"]
  PUID                  = module.common.resolved_variables["PUID"]
  PGID                  = module.common.resolved_variables["PGID"]
  WAN_NETWORKS          = var.WAN_NETWORKS
}

# GitHub Runner Configuration
module "runner" {
  source                 = "./modules/runner"
  SERVER_HOST            = module.common.resolved_variables["GITHUB_SERVER_HOST"]
  SSH_USER               = module.common.resolved_variables["GITHUB_SSH_USER"]
  SSH_PRIVATE_KEY        = module.common.resolved_variables["GITHUB_SSH_PRIVATE_KEY"]
  GITHUB_REPO_NAME       = module.common.resolved_variables["GITHUB_REPO_NAME"]
  GITHUB_TOKEN           = module.common.resolved_variables["GITHUB_TOKEN"]
  GITHUB_SSH_USER        = module.common.resolved_variables["GITHUB_SSH_USER"]
  GITHUB_SERVER_HOST     = module.common.resolved_variables["GITHUB_SERVER_HOST"]
  GITHUB_SSH_PRIVATE_KEY = module.common.resolved_variables["GITHUB_SSH_PRIVATE_KEY"]
  GITHUB_RUNNER_TOKEN    = module.common.resolved_variables["GITHUB_RUNNER_TOKEN"]
  RUNNER_NAME            = module.common.resolved_variables["RUNNER_NAME"]
  RUNNER_DIR             = module.common.resolved_variables["RUNNER_DIR"]
  RUNNER_VERSION         = module.common.resolved_variables["RUNNER_VERSION"]
  RUNNER_HASH            = module.common.resolved_variables["RUNNER_HASH"]
}