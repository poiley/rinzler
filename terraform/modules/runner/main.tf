terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Remove existing runner
resource "null_resource" "remove_runner" {
  triggers = {
    runner_dir = var.RUNNER_DIR
  }

  provisioner "remote-exec" {
    connection {
      host        = var.SERVER_HOST
      user        = var.SSH_USER
      private_key = var.SSH_PRIVATE_KEY
    }

    inline = [
      "if [ -d ${var.RUNNER_DIR} ]; then",
      "  cd ${var.RUNNER_DIR}",
      "  ./config.sh remove --token ${var.GITHUB_RUNNER_TOKEN}",
      "  rm -rf ${var.RUNNER_DIR}",
      "fi"
    ]
  }
}

# Setup new runner
resource "null_resource" "github_runner" {
  connection {
    type        = "ssh"
    host        = var.SERVER_HOST
    user        = var.SSH_USER
    private_key = var.SSH_PRIVATE_KEY
  }

  provisioner "remote-exec" {
    inline = [
      # Create runner directory
      "sudo mkdir -p ${var.RUNNER_DIR}",
      "sudo chown ${var.SSH_USER}:${var.SSH_USER} ${var.RUNNER_DIR}",

      # Download and install runner
      "cd ${var.RUNNER_DIR}",
      "curl -o actions-runner-linux-x64-${var.RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${var.RUNNER_VERSION}/actions-runner-linux-x64-${var.RUNNER_VERSION}.tar.gz",
      "echo '${var.RUNNER_HASH} actions-runner-linux-x64-${var.RUNNER_VERSION}.tar.gz' | sha256sum -c",
      "tar xzf ./actions-runner-linux-x64-${var.RUNNER_VERSION}.tar.gz",

      # Configure runner
      "./config.sh --url https://github.com/${var.GITHUB_REPO_NAME} --token ${var.GITHUB_RUNNER_TOKEN} --name ${var.RUNNER_NAME} --unattended",

      # Configure SSH for GitHub
      "echo '${var.GITHUB_SSH_PRIVATE_KEY}' > ~/.ssh/github",
      "chmod 600 ~/.ssh/github",
      "cat > ~/.ssh/config << 'EOF'",
      "Host github.com",
      "  User ${var.GITHUB_SSH_USER}",
      "  HostName ${var.GITHUB_SERVER_HOST}",
      "  IdentityFile ~/.ssh/github",
      "  StrictHostKeyChecking no",
      "EOF",

      # Start runner service
      "./svc.sh install",
      "./svc.sh start"
    ]
  }
} 