terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# GitHub Repository and Runner Group
resource "github_repository" "repo" {
  name       = var.repository_name
  visibility = "public"
}

resource "github_actions_runner_group" "runner_group" {
  name       = var.repository_name
  visibility = "private"
}

# GitHub Secrets
resource "github_actions_secret" "unifi_api_key" {
  repository      = var.repository_name
  secret_name     = "UNIFI_API_KEY"
  plaintext_value = var.unifi_api_key
}

resource "github_actions_secret" "pihole_api_token" {
  repository      = var.repository_name
  secret_name     = "PIHOLE_API_TOKEN"
  plaintext_value = var.pihole_api_token
}

resource "github_actions_secret" "runner_token" {
  repository      = var.repository_name
  secret_name     = "RUNNER_TOKEN"
  plaintext_value = var.runner_token
}

resource "github_actions_secret" "ssh_private_key" {
  repository      = var.repository_name
  secret_name     = "SSH_PRIVATE_KEY"
  plaintext_value = var.ssh_private_key
}

resource "github_actions_secret" "server_host" {
  repository      = var.repository_name
  secret_name     = "SERVER_HOST"
  plaintext_value = var.server_host
}

resource "github_actions_secret" "ssh_user" {
  repository      = var.repository_name
  secret_name     = "SSH_USER"
  plaintext_value = var.ssh_user
}

# Remove existing runner
resource "null_resource" "remove_runner" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = var.ssh_private_key
    host        = var.server_host
  }

  provisioner "remote-exec" {
    inline = [
      "if [ -d ${var.runner_dir} ]; then",
      "  cd ${var.runner_dir}",
      "  ./config.sh remove --token ${var.runner_token}",
      "  rm -rf ${var.runner_dir}",
      "fi"
    ]
  }
}

# Setup new runner
resource "null_resource" "github_runner" {
  depends_on = [null_resource.remove_runner, github_repository.repo]

  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = var.ssh_private_key
    host        = var.server_host
  }

  provisioner "remote-exec" {
    inline = [
      # Create runner directory
      "sudo mkdir -p ${var.runner_dir}",
      "sudo chown ${var.ssh_user}:${var.ssh_user} ${var.runner_dir}",

      # Download and install runner
      "cd ${var.runner_dir}",
      "curl -o actions-runner-linux-x64-${var.runner_version}.tar.gz -L https://github.com/actions/runner/releases/download/v${var.runner_version}/actions-runner-linux-x64-${var.runner_version}.tar.gz",
      "echo '${var.runner_hash} actions-runner-linux-x64-${var.runner_version}.tar.gz' | sha256sum -c",
      "tar xzf ./actions-runner-linux-x64-${var.runner_version}.tar.gz",

      # Configure runner
      "./config.sh --url https://github.com/${var.github_owner}/${var.repository_name} --token ${var.runner_token} --name ${var.runner_name} --unattended",

      # Configure SSH for GitHub
      "mkdir -p ~/.ssh",
      "echo '${var.ssh_private_key}' > ~/.ssh/github",
      "chmod 600 ~/.ssh/github",
      "cat > ~/.ssh/config << 'EOF'",
      "Host github.com",
      "  User ${var.ssh_user}",
      "  HostName ${var.server_host}",
      "  IdentityFile ~/.ssh/github",
      "  StrictHostKeyChecking no",
      "EOF",
      "chmod 600 ~/.ssh/config",

      # Start runner service
      "sudo ./svc.sh install",
      "sudo ./svc.sh start"
    ]
  }
} 