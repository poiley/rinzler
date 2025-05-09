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
  username       = var.unifi_username
  password       = var.unifi_password
  api_url        = var.unifi_controller_url
  allow_insecure = true
}

provider "pihole" {
  url       = var.pihole_url
  api_token = var.pihole_api_token
}

provider "docker" {}

# UniFi Network Configuration
module "unifi" {
  source               = "./modules/unifi"
  unifi_api_key        = var.unifi_api_key
  unifi_controller_url = var.unifi_controller_url
  unifi_username       = var.unifi_username
  unifi_password       = var.unifi_password
  unifi_site           = var.unifi_site
  network              = var.network
  wan_networks         = var.wan_networks
  port_forwards        = var.port_forwards
}

# Pi-hole DNS Configuration
module "pihole" {
  source           = "./modules/pihole"
  pihole_url       = var.pihole_url
  pihole_api_token = var.pihole_api_token
  dns_records      = var.dns_records
  pihole_password  = var.pihole_password
}

# Server Bootstrap Configuration
module "bootstrap" {
  source = "./modules/bootstrap"

  server_host           = var.server_host
  ssh_user              = var.ssh_user
  ssh_private_key       = var.ssh_private_key
  packages              = var.packages
  repo_url              = var.repo_url
  repo_branch           = var.repo_branch
  repo_path             = var.repo_path
  env_vars              = var.env_vars
  zfs_pool              = var.zfs_pool
  zfs_dataset           = var.zfs_dataset
  github_token          = var.github_token
  github_owner          = var.github_owner
  repository_name       = var.github_repo_name
  unifi_api_key         = var.unifi_api_key
  pihole_api_token      = var.pihole_api_token
  runner_token          = var.github_runner_token
  pihole_url            = var.pihole_url
  unifi_controller_url  = var.unifi_controller_url
  unifi_username        = var.unifi_username
  unifi_password        = var.unifi_password
  unifi_site            = var.unifi_site
  dockge_stacks_dir     = var.dockge_stacks_dir
  wireguard_private_key = var.wireguard_private_key
  wireguard_addresses   = var.wireguard_addresses
  pihole_password       = var.pihole_password
  basic_auth_header     = var.basic_auth_header
  puid                  = var.puid
  pgid                  = var.pgid
  wan_networks          = var.wan_networks
  timezone              = var.timezone
}

# GitHub Runner Configuration
module "runner" {
  source = "./modules/runner"

  # GitHub Configuration
  github_token           = var.github_token
  github_owner           = var.github_owner
  repository_name        = var.github_repo_name
  github_repo_name       = var.github_repo_name
  github_ssh_user        = var.github_ssh_user
  github_server_host     = var.github_server_host
  github_ssh_private_key = var.github_ssh_private_key
  unifi_api_key          = var.unifi_api_key
  pihole_api_token       = var.pihole_api_token
  runner_token           = var.github_runner_token

  # Runner Configuration
  server_host     = var.server_host
  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_private_key
  runner_name     = var.runner_name
  runner_dir      = var.runner_dir
  runner_version  = var.runner_version
  runner_hash     = var.runner_hash
}